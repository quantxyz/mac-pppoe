//
//  pppoeOperation.m
//  pppoe
//
//  Created by Jerry Smith on 1/01/16.
//  Copyright © 2016 Jerry Smith. All rights reserved.
//

#include <assert.h>
#include <unistd.h>
#include <stdlib.h>

#import "pppoeOperation.h"
int pppoeInterfaceNum=0;
static char* xstrdup(const char* s)
{
	int len = strlen(s) +1;
	char* ret = malloc(sizeof(char) * len);
	if (ret) memcpy(ret, s, len);
	return ret;
}

static SCNetworkConnectionPPPStatus GetMinorStatus(
    SCNetworkConnectionRef connection
)
    // Gets the minor connection status from the extended status 
    // dictionary associated with the connection.  Returns -1 if 
    // it can't get the status, for whatever reason.
{
    SCNetworkConnectionPPPStatus    result;
    CFDictionaryRef                 statusDict;
    CFDictionaryRef                 pppDict;
    CFNumberRef                     minorStatusNum;
    
    result = -1;
    
    // Get the extended status dictionary.
    
    statusDict = SCNetworkConnectionCopyExtendedStatus(connection);
    if (statusDict != NULL) {
    
        // Extract the PPP sub-dictionary.
        
        pppDict = CFDictionaryGetValue(statusDict, kSCEntNetPPP);
        
        if (  (pppDict != NULL) 
           && (CFGetTypeID(pppDict) == CFDictionaryGetTypeID()) 
           ) {
           
            // Extract the minor status value.
            
            minorStatusNum = CFDictionaryGetValue(
                pppDict, 
                kSCPropNetPPPStatus
            );
            
            if (  (minorStatusNum != NULL) 
               && (CFGetTypeID(minorStatusNum) == CFNumberGetTypeID()) 
               ) {
                SInt32 tmp;
                
                if ( CFNumberGetValue(
                         minorStatusNum, 
                        kCFNumberSInt32Type, &tmp
                     ) 
                   ) {
                    result = tmp;
                }
            }
        }
        CFRelease(statusDict);
    }
    return result;
}

static void MyNetworkConnectionCallBack(
    SCNetworkConnectionRef          connection,
    SCNetworkConnectionStatus       status,
    void                            *info
)
{
    SCNetworkConnectionPPPStatus    minorStatus;
    
    assert(connection != NULL);
 
    //status = SCNetworkConnectionGetStatus(connection);
    
    // Get the minor status from the extended status associated with 
    // the connection.
    minorStatus = GetMinorStatus(connection);
    

    // If we hit either the connected or disconnected state, 
    // we signal the runloop to stop so that the main function 
    // can process the result of the [dis]connection attempt.
    
    if (  (  minorStatus == kSCNetworkConnectionPPPDisconnected )
	   || (  minorStatus == kSCNetworkConnectionPPPConnected    ) 
       ) {
        CFRunLoopStop(CFRunLoopGetCurrent());
    }
}

static int pppConnect(SCNetworkConnectionRef connection, DialParas* data) {
    int                     err;
    Boolean                 ok;
	CFDictionaryRef			optionsForDial;
	CFDictionaryRef			pppOptionsForDial;
	
	optionsForDial = NULL;
	pppOptionsForDial = NULL;
	
    err = 0;
	if (connection == NULL) err = EINVAL;
	if (err == 0) {
		CFStringRef keys[3] = { NULL, NULL, NULL };
		CFStringRef vals[3] = { NULL, NULL, NULL };
		CFIndex numkeys = 0;
		keys[numkeys] = kSCPropNetPPPAuthName;
		vals[numkeys++] = CFStringCreateWithCString(NULL, data->uName, kCFStringEncodingUTF8);
		keys[numkeys] = kSCPropNetPPPAuthPassword;
		vals[numkeys++] = CFStringCreateWithCString(NULL, data->pwd, kCFStringEncodingUTF8);
		keys[numkeys] = kSCPropNetPPPCommRemoteAddress;
		vals[numkeys++] = CFStringCreateWithCString(NULL, data->sName, kCFStringEncodingUTF8);

		// create "PPP" options
		pppOptionsForDial = CFDictionaryCreate(NULL, (const void **)&keys, (const void **)&vals, numkeys, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

		numkeys = 0;
		keys[numkeys] = kSCEntNetPPP;
		vals[numkeys++] = pppOptionsForDial;
        

		// create "connection" options
		optionsForDial = CFDictionaryCreate(NULL, (const void **)&keys, (const void **)&vals, numkeys, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	}

    // Schedule our callback with the runloop.
    if (err == 0) {
        ok = SCNetworkConnectionScheduleWithRunLoop(
            connection,
            CFRunLoopGetCurrent(),
            kCFRunLoopDefaultMode
        );
        if ( ! ok ) {
            err = SCError();
        }
    }
	
    // Check the status.  If we're already connected tell the user. 
    // If we're not connected, initiate the connection.
    
    if (err == 0) {
        err = ECANCELED;    // Most cases involve us bailing out, 
                            // so set the error here.
        
        switch ( SCNetworkConnectionGetStatus(connection) ) {
            case kSCNetworkConnectionDisconnected:
				err = 0;
                break;
            case kSCNetworkConnectionConnecting:
                fprintf(stderr, "Service is already connecting.\n");
                break;
            case kSCNetworkConnectionDisconnecting:
                fprintf(stderr, "Service is disconnecting.\n");
                break;
            case kSCNetworkConnectionConnected:
                fprintf(stderr, "Service is already connected.\n");
                break;
            case kSCNetworkConnectionInvalid:
                fprintf(stderr, "Service is invalid.  Weird.\n");
                break;
            default:
                fprintf(stderr, "Unexpected status.\n");
                break;
        }
    }
    
    // Initiate the connection.

	if (err == 0) {
		ok = SCNetworkConnectionStart(connection,optionsForDial,TRUE);
		if ( ! ok ) {
			err = SCError();
		}
	}

    // Run the runloop and wait for our connection attempt to be resolved. 
    // Once that happens, print the result.
    if (err == 0) {
        CFRunLoopRun();
	
        switch (GetMinorStatus(connection)) {
            case kSCNetworkConnectionPPPConnected:
                fprintf(stderr, "Connection succeeded\n");
                break;
            case kSCNetworkConnectionPPPDisconnected:
                fprintf(stderr, "Connection failed\n");
                err = ECANCELED;
                break;
            default:
                fprintf(
                    stderr, 
                    "Still in connecting\n" 
                );
                err = EINVAL;
                break;
        }
    }

    if (optionsForDial != NULL) {
        CFRelease(optionsForDial);
    }
    if (pppOptionsForDial != NULL) {
        CFRelease(pppOptionsForDial);
    }
    if (connection != NULL) {
        (void) SCNetworkConnectionUnscheduleFromRunLoop(
            connection,
            CFRunLoopGetCurrent(),
            kCFRunLoopDefaultMode
        );
    }

    if (err == 0) {
        return EXIT_SUCCESS;
    } else {
        return EXIT_FAILURE;
    }
}

static int pppDisconnect(SCNetworkConnectionRef connection) {
    int                     err;
    Boolean                 ok;
    
    err = 0;
	
    // Schedule our callback with the runloop.
	ok = SCNetworkConnectionScheduleWithRunLoop(
		connection,
		CFRunLoopGetCurrent(),
		kCFRunLoopDefaultMode
	);
	if ( ! ok ) {
		err = SCError();
	}
    
    if (err == 0) {
        err = ECANCELED;    // Most cases involve us bailing out, 
                            // so set the error here.
        
        switch ( SCNetworkConnectionGetStatus(connection) ) {
            case kSCNetworkConnectionDisconnected:
                break;
            case kSCNetworkConnectionConnecting:
                err = 0;
                fprintf(stderr, "Service is connecting.\n");
                break;
            case kSCNetworkConnectionDisconnecting:
                fprintf(stderr, "Service is disconnecting.\n");
                break;
            case kSCNetworkConnectionConnected:
                err = 0;
                fprintf(stderr, "Service is connected.\n");
                break;
            case kSCNetworkConnectionInvalid:
                fprintf(stderr, "Service is invalid.  Weird.\n");
                break;
            default:
                fprintf(stderr, "Unexpected status.\n");
                break;
        }
    }
    
    if (err == 0) {
		// Initiate a disconnect.

        ok = SCNetworkConnectionStop(
            connection,
            true
        );
        if ( ! ok ) {
            err = SCError();
        }
    }
    
    // Run the runloop and wait for our disconnection attempt to be 
    // resolved.  Once that happens, print the result.

    if (err == 0) {
        CFRunLoopRun();
        
        switch (GetMinorStatus(connection)) {
            case kSCNetworkConnectionPPPDisconnected:
                fprintf(stderr, "Disconnection succeeded\n");
                break;
            case kSCNetworkConnectionPPPConnected:
                fprintf(stderr, "Disconnection failed\n");
                err = ECANCELED;
                break;
            default:
                fprintf(
                    stderr, 
                    "Bad Status \n"
                );
                err = EINVAL;
                break;
        }
    }

    // Clean up.
    
    if (connection != NULL) {
        (void) SCNetworkConnectionUnscheduleFromRunLoop(
            connection,
            CFRunLoopGetCurrent(),
            kCFRunLoopDefaultMode
        );
    }
    if (err == 0) {
        return EXIT_SUCCESS;
    } else {
        return EXIT_FAILURE;
    }
}

@implementation pppoeOperation
- (id)initWithData:(DialParas*)data {
    if (![super init]) return nil;
	
	if (!data->uName) return nil;
	if (!data->pwd) return nil;
	//if (!data->sName) return nil;
	dialData.uName = xstrdup(data->uName);
	dialData.pwd = xstrdup(data->pwd);
	dialData.sName = xstrdup(data->sName);
    dialData.connectType = data->connectType;
	dialData.cmd = data->cmd;
	return self;
}

- (void)dealloc {
	if (dialData.uName) {
		free(dialData.uName);
		dialData.uName = nil;
	}
	if (dialData.pwd) {
		free(dialData.pwd);
		dialData.pwd = nil;
	}
	if (dialData.sName) {
		free(dialData.sName);
		dialData.sName = nil;
	}
	[super dealloc];
}

- (void)setPPPStatus:(PPPStatus)status {
	NSNumber* statusNum = [NSNumber numberWithInt:status];
	[[pppoeGUI shared] performSelectorOnMainThread:@selector(setPPPStatus:)
													withObject:statusNum
													waitUntilDone:YES];
}

- (void)main {
    SCPreferencesRef        prefs;
	AuthorizationRef		auth;
	OSStatus				authErr;
	SCNetworkSetRef			set;
	SCNetworkServiceRef		service, networkServiceRef;
	SCNetworkInterfaceRef	handwareInterface, networkInterface;
	CFArrayRef				allNetworkServices;
    CFStringRef             serviceToDial;
    CFDictionaryRef         optionsForDial;
	SCNetworkConnectionRef	connection;
	
	prefs = NULL;
	auth = NULL;
	authErr = noErr;
	set = NULL;
	service = NULL;
	handwareInterface = NULL;
	networkInterface = NULL;
	networkServiceRef = NULL;
	allNetworkServices = NULL;
	serviceToDial = NULL;
	optionsForDial = NULL;
	connection = NULL;
    printf("pppoeInterfaceNum init:%d\n", pppoeInterfaceNum);
	//find a useable PPP service first
	AuthorizationFlags rootFlags = kAuthorizationFlagDefaults
								|  kAuthorizationFlagExtendRights
								|  kAuthorizationFlagInteractionAllowed
								|  kAuthorizationFlagPreAuthorize;
	authErr = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, rootFlags, &auth);
	if (authErr == noErr)
		prefs = SCPreferencesCreateWithAuthorization(NULL, CFSTR("com.cppfun.pppoe"), NULL, auth);
	else
		prefs = SCPreferencesCreate(NULL, CFSTR("com.cppfun.pppoe"), NULL);

    
	if (prefs) allNetworkServices = SCNetworkServiceCopyAll(prefs);
	if (allNetworkServices == nil) return;
	CFIndex countServices = CFArrayGetCount(allNetworkServices);
    bool found=false;
	for (int num = 0;num < countServices;++num) {
		networkServiceRef = (SCNetworkServiceRef) CFArrayGetValueAtIndex(allNetworkServices, num);
		networkInterface = SCNetworkServiceGetInterface(networkServiceRef);
        if (SCNetworkInterfaceGetInterfaceType(networkInterface) == kSCNetworkInterfaceTypeModem) {
            continue;
        }
		if (SCNetworkInterfaceGetInterfaceType(networkInterface) == kSCNetworkInterfaceTypePPP) {
			handwareInterface = SCNetworkInterfaceGetInterface(networkInterface);
			if (handwareInterface && (SCNetworkInterfaceGetInterfaceType(handwareInterface) == kSCNetworkInterfaceTypeEthernet)) {
                if(dialData.connectType==1) {
                    serviceToDial = SCNetworkServiceGetServiceID(networkServiceRef);
                    //found one
                    connection = SCNetworkConnectionCreateWithServiceID(
                        NULL,serviceToDial,MyNetworkConnectionCallBack,NULL
                    );
                    found=true;
                    pppoeInterfaceNum=1;
                    printf("pppoeInterfaceNum from Ethernet: %d\n", pppoeInterfaceNum);
                    break;
                }
            }
            if (handwareInterface && (SCNetworkInterfaceGetInterfaceType(handwareInterface) == kSCNetworkInterfaceTypeIEEE80211)) {
                if(dialData.connectType==0) {
                    serviceToDial = SCNetworkServiceGetServiceID(networkServiceRef);	//found one
                    connection = SCNetworkConnectionCreateWithServiceID(
                        NULL,serviceToDial,MyNetworkConnectionCallBack,NULL
                    );
                    found=true;
                    pppoeInterfaceNum=1;
                    printf("pppoeInterfaceNum from IEEE80211: %d\n", pppoeInterfaceNum);
                    break;
                }// if
            }
		} // end if
	}
    if (pppoeInterfaceNum==0) {
        // just get the Ethernet or Airport handware interface
        for (int num = 0;num < countServices;++num) {
            networkServiceRef = (SCNetworkServiceRef) CFArrayGetValueAtIndex(allNetworkServices, num);
            networkInterface = SCNetworkServiceGetInterface(networkServiceRef);
            if (SCNetworkInterfaceGetInterfaceType(networkInterface) == kSCNetworkInterfaceTypeEthernet && dialData.connectType==1) {
                handwareInterface = networkInterface;
                break;
            }
            if (SCNetworkInterfaceGetInterfaceType(networkInterface) == kSCNetworkInterfaceTypeIEEE80211 && dialData.connectType==0) {
                handwareInterface = networkInterface;
                break;
            }
        }
    }
    
	if (!found && pppoeInterfaceNum==0) {
        //no PPP service based on ethernet available, create and use it
        //SCNetworkInterfaceRef interface;
		if (handwareInterface && SCPreferencesLock(prefs, TRUE))
        {
            networkInterface = SCNetworkInterfaceCreateWithInterface(handwareInterface, kSCValNetInterfaceTypePPP);
            pppoeInterfaceNum=1;
            printf("pppoeInterfaceNum from PPP:%d\n", pppoeInterfaceNum);
        }

		if (prefs && networkInterface) {
			service = SCNetworkServiceCreate(prefs,networkInterface);
            CFStringRef serviceName=CFSTR("Ethernet PPPoE");
            if (dialData.connectType==0) {
                serviceName=CFSTR("AirPort PPPoE");
            }
            if (strlen(dialData.sName)>0) {
                serviceName=CFStringCreateWithCString(NULL, dialData.sName, kCFStringEncodingUTF8);
            }
			SCNetworkServiceSetName(service, serviceName);
			networkInterface = SCNetworkServiceGetInterface(service);	//have to do this, seems IfRef changed after service creation
            // add uName and sName to "PPP" options
			
            CFDictionaryRef oldOptions = SCNetworkInterfaceGetConfiguration(networkInterface);
			CFIndex i = CFDictionaryGetCount(oldOptions);
			CFMutableDictionaryRef pppOptions = CFDictionaryCreateMutableCopy(NULL, i + 2, oldOptions);
            CFStringRef uname=CFStringCreateWithCString(NULL, dialData.uName, kCFStringEncodingUTF8);
			CFDictionaryAddValue(pppOptions, kSCPropNetPPPAuthName,uname);
            CFStringRef upwd=CFStringCreateWithCString(NULL, dialData.pwd, kCFStringEncodingUTF8);
			CFDictionaryAddValue(pppOptions, kSCPropNetPPPAuthPassword, upwd);
            bool success=SCNetworkInterfaceSetConfiguration(networkInterface, pppOptions);
            if(success) {printf("Set interface success\n");}
			CFRelease(pppOptions);
			
			if (SCNetworkServiceEstablishDefaultConfiguration(service)) {
				set = SCNetworkSetCopyCurrent(prefs);
				if (set && SCNetworkSetAddService(set, service)) {
					SCPreferencesCommitChanges(prefs);
					SCPreferencesApplyChanges(prefs);
					serviceToDial = SCNetworkServiceGetServiceID(service);
					connection = SCNetworkConnectionCreateWithServiceID(
						NULL,
						serviceToDial, 
						MyNetworkConnectionCallBack,
						NULL
					);
				}
			}
			SCPreferencesUnlock(prefs);
		}
	}
	
	SCNetworkConnectionStatus status = SCNetworkConnectionGetStatus(connection);
	if (dialData.cmd == kPPPDisconnect) {
		if (status != kSCNetworkConnectionDisconnected) pppDisconnect(connection);
		[self setPPPStatus:kPPPDisconnected];
	} else if (dialData.cmd == kPPPConnect) {
		if (![self isCancelled] && (status != kSCNetworkConnectionConnected) && (status != kSCNetworkConnectionConnecting)) {
			pppConnect(connection, &dialData);
			status = SCNetworkConnectionGetStatus(connection);
			if (status == kSCNetworkConnectionConnected) [self setPPPStatus:kPPPConnected];
			if (status == kSCNetworkConnectionDisconnected) [self setPPPStatus:kPPPDisconnected];
		}
	}
	
	if (prefs) CFRelease(prefs);
	if (set) CFRelease(set);
	if (service) CFRelease(service);
	if (allNetworkServices) CFRelease(allNetworkServices);
	if (serviceToDial) CFRelease(serviceToDial);
	if (optionsForDial) CFRelease(optionsForDial);
	//if (connection) CFRelease(connection);	//have no idea why this can cause a problem
}
@end

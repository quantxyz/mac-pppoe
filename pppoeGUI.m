#import "pppoeGUI.h"
#import "pppoeOperation.h"

const NSString *curl=@"http://dev.cppfun.com/pppoe.txt";
const int ccurrVesion=1;

@implementation pppoeGUI
static pppoeGUI* shared;

- (id)init {
	if (shared) {
		[self autorelease];
		return shared;
	}
	if (![super init]) return nil;
	queue = [[NSOperationQueue alloc] init];
	tStatus = kConnectTitle;
	pppStatus = kPPPDisconnect;
	theTimer = nil;
	shared = self;
	return self;
}

- (void)dealloc {
	[queue release], queue = nil;
	if (theTimer) {
		[theTimer invalidate];
		theTimer = nil;
	}
	[super dealloc];
}

+ (id)shared {
	if (!shared) {
		[[pppoeGUI alloc] init];
	}
	return shared;
}

- (IBAction)helpAction:(id)sender {
	NSAlert* alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", NULL)];
	[alert setMessageText:NSLocalizedString(@"A special ppp dialup program for special people.\n\nFirst two characters \"\\r\\n\" of real name not displayed.", NULL)];
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert runModal];
	[alert release];
}

- (IBAction)cButtonAction:(id)sender {
/*	if (pppStatus == kPPPInvalid) {		//wont't reach here, comment out
		NSAlert* alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:NSLocalizedString(@"OK", NULL)];
		[alert setMessageText:NSLocalizedString(@"Usable ppp service not found.", NULL)];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert runModal];
		[alert release];
		return;
	} */
	if (tStatus == kConnectTitle) {
		[cButton setTitle:NSLocalizedString(@"cancel", NULL)];
		tStatus = kCancelTitle;
		pppStatus = kPPPConnecting;
		[pBar setDoubleValue:0.0];
		[statusTF setStringValue:NSLocalizedString(@"connecting...", NULL)];
		[self addOperation:kPPPConnect];
		count = 0;
		theTimer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(theTimerControl:) userInfo:nil repeats:YES];
	} else {
		if (theTimer) [theTimer invalidate];
		theTimer = nil;
		if (queue) [queue cancelAllOperations];
		[self addOperation:kPPPDisconnect];
		
		[cButton setTitle:NSLocalizedString(@"connect", NULL)];
		tStatus = kConnectTitle;
		pppStatus = kPPPDisconnected;
		[pBar setDoubleValue:0.0];
		[statusTF setStringValue:NSLocalizedString(@"not connected", NULL)];
	}
}
- (IBAction)ethernetAction:(id)sender
{
    [eRadioButton setState:(NSOnState)];
    [aRadioButton setState:(NSOffState)];
}
- (IBAction)airportAction:(id)sender
{
    [eRadioButton setState:(NSOffState)];
    [aRadioButton setState:(NSOnState)];
}
-(NSAttributedString *)stringFromHTML:(NSString *)html withFont:(NSFont *)font
{
    if (!font) font = [NSFont systemFontOfSize:0.0];  // Default font
    html = [NSString stringWithFormat:@"<span style=\"font-family:'%@'; font-size:%dpx;\">%@</span>", [font fontName], (int)[font pointSize], html];
    NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
    NSAttributedString* string = [[NSAttributedString alloc] initWithHTML:data documentAttributes:nil];
    return string;
}

- (void)checkUpdate:(const NSString *)url version:(int)currVesion {
    // osx can make the app with 32bit and 64bit together
    // so we do need the Ostype request field on osx
    // http://dev.cppfun.com/pppoe.txt?CurrVersion=1
    NSString *realUrl = [NSString stringWithFormat:@"%@?CurrVersion=%d", url, currVesion];
    
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:[NSURL URLWithString:realUrl]
            completionHandler:^(NSData *data,
                                NSURLResponse *response,
                                NSError *error) {
                // handle response
                if (!data) {
                    NSLog(@"fetch failed: %@", [error localizedDescription]);
                }
                NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSArray *results = [result componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
                NSMutableDictionary *all = [[NSMutableDictionary alloc] init];
                for (NSString *str in results) {
                    NSArray *keyAndValue = [str componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
                    int len = [keyAndValue count];
                    if (len<2) {
                        [all setObject:@"" forKey:keyAndValue[0]];
                    } else {
                        [all setObject:keyAndValue[1] forKey:keyAndValue[0]];
                    }
                }
                /*
                VersionId=2
                VersionName=appname
                Size=8907
                Filenum=1
                Link=http://url/mac_client.zip
                */
                // compare two version
                int VersionId=[all[@"VersionId"] intValue];
                if (VersionId > currVesion) {
                    // wait me
                    [updateAction setAllowsEditingTextAttributes: YES];
                    [updateAction setSelectable:YES];
                    [updateLabel setStringValue:NSLocalizedString(@"updateLabel", NULL)];
                    NSString *updateUrl = [NSString stringWithFormat:@"<a href=\"%@\" style='color:red;'>Update!</a>", all[@"Link"]];
                    [updateAction setAttributedStringValue:[self stringFromHTML:updateUrl withFont:[updateAction font]]];
                }
            }] resume];
    
}
- (void)theTimerControl:(NSTimer *)aTimer {
	if ((pppStatus == kPPPConnecting) || (pppStatus == kPPPInvalid)) {
        //theoretically won't be kPPPInvalid, but...
        [cButton setEnabled:false];
		count++;
		double val = [aTimer timeInterval] * count;
		[statusTF setStringValue:[NSString stringWithFormat:NSLocalizedString(@"connecting time: %2.0fs", NULL), val]];
		while (val > 10) val -= 10;
		[pBar setDoubleValue:(val * 100.0 / 10.0)];
	} else {
        [cButton setEnabled:true];
			if (queue) [queue cancelAllOperations];
			if (theTimer) [theTimer invalidate];
			theTimer = nil;
			if (pppStatus == kPPPConnected) {
				[cButton setTitle:NSLocalizedString(@"Disconnect", NULL)];
				tStatus = kDisconnectTitle;
				[pBar setDoubleValue:100.0];
				[statusTF setStringValue:NSLocalizedString(@"connected", NULL)];
                // here do some update check
                [self checkUpdate:curl version:ccurrVesion];
			} else {
				[cButton setTitle:NSLocalizedString(@"connect", NULL)];
				tStatus = kConnectTitle;
				[pBar setDoubleValue:0.0];
				[statusTF setStringValue:NSLocalizedString(@"connect failed", NULL)];
			}
	}
}

- (IBAction)qButtonAction:(id)sender {
    // update for cancel begin
    if (queue) [queue cancelAllOperations];
    if (tStatus == kDisconnectTitle || tStatus == kCancelTitle) {
        [self addOperation:kPPPDisconnect];
    }
    // update for cancel endl
	[[NSApplication sharedApplication] terminate:sender];
}

- (void)addOperation:(PPPCMD)cmd {
	DialParas data;
	char* uName = (char*) [[uNameTF stringValue] UTF8String];
	data.uName = uName;
	data.pwd = (char*) [[pwdTF stringValue] UTF8String];
	data.sName = (char*) [[sNameTF stringValue] UTF8String];
    data.connectType=[eRadioButton intValue];
    printf("connectType %d\n",data.connectType);
	data.cmd = cmd;
	pppoeOperation* dialOp = [[pppoeOperation alloc] initWithData:&data];
	if (queue&&dialOp) [queue addOperation:dialOp];
}

- (void) settingRestore {
	NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
	
	NSString* str;
	str = [defaults stringForKey:@"userName"];
	if (str != nil) [uNameTF setStringValue:str];
	str = [defaults stringForKey:@"serviceName"];
	if (str != nil) [sNameTF setStringValue:str];
	str = [defaults stringForKey:@"password"];
	if (str != nil) [pwdTF setStringValue:str];
	[acCheckBox setIntValue:[defaults integerForKey:@"autoConnect"]];
    [eRadioButton setIntValue:[defaults integerForKey:@"ethernetType"]];
    [aRadioButton setIntValue:[defaults integerForKey:@"airportType"]];
}

- (void) settingSave {
	NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
	
	[defaults setObject:[uNameTF stringValue] forKey:@"userName"];
	[defaults setObject:[sNameTF stringValue] forKey:@"serviceName"];
	[defaults setObject:[pwdTF stringValue] forKey:@"password"];
	[defaults setInteger:[acCheckBox intValue] forKey:@"autoConnect"];
    [defaults setInteger:[eRadioButton intValue] forKey:@"ethernetType"];
    [defaults setInteger:[aRadioButton intValue] forKey:@"airportType"];
}

- (void) awakeFromNib {
	[self settingRestore];
	if ([acCheckBox intValue]) [self cButtonAction:NULL];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	if (queue) [queue cancelAllOperations];
	[self settingSave];
}

- (void)setPPPStatus:(NSNumber*)num {
	pppStatus = (PPPStatus) [num intValue];
}
@end

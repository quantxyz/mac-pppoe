//
//  pppoeOperation.h
//  pppoe
//
//  Created by Jerry Smith on 1/01/16.
//  Copyright © 2016 Jerry Smith. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <CoreFoundation/CoreFoundation.h>
#include <SystemConfiguration/SystemConfiguration.h>
#import "pppoeGUI.h"

@interface pppoeOperation : NSOperation
{
    DialParas dialData;
}
- (id)initWithData:(DialParas*)data;
- (void)setPPPStatus:(PPPStatus)status;
@end

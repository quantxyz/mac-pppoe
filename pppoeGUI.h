#import <Cocoa/Cocoa.h>

typedef enum _TitleStatus {
	kUnknownTitle = 0,
	kConnectTitle = 1,
	kCancelTitle = 2,
	kDisconnectTitle = 3
} TitleStatus;

typedef enum _PPPStatus {
	kPPPInvalid = 0, 
	kPPPDisconnected = 1,
	kPPPConnecting = 2,
	kPPPConnected = 3
} PPPStatus;

typedef enum _PPPCMD {
	kPPPConnect = 0,
	kPPPDisconnect = 1
} PPPCMD;

typedef struct _Parameters {
	char* uName;
	char* pwd;
	char* sName;
    int connectType;
	PPPCMD cmd;
} DialParas;

@interface pppoeGUI:NSObject {
    IBOutlet NSButton* acCheckBox;
    IBOutlet NSButton* cButton;
    IBOutlet NSProgressIndicator* pBar;
    IBOutlet NSTextField* pwdTF;
    IBOutlet NSTextField* sNameTF;
    IBOutlet NSTextField* statusTF;
    IBOutlet NSTextField* uNameTF;
    // add for airport begin
    IBOutlet NSButton* eRadioButton;
    IBOutlet NSButton* aRadioButton;
    // add for airport endl
    // add for update begin
    IBOutlet NSTextField* updateAction;
    IBOutlet NSTextField* updateLabel;
    // add for update endl
	
	NSOperationQueue* queue;
	TitleStatus tStatus;
	PPPStatus pppStatus;
	NSTimer *theTimer;
	int count;
}
- (IBAction)cButtonAction:(id)sender;
// add for airport begin
- (IBAction)ethernetAction:(id)sender;
- (IBAction)airportAction:(id)sender;
// add for airport endl
- (void)theTimerControl:(NSTimer*)aTimer;
- (IBAction)qButtonAction:(id)sender;
- (IBAction)helpAction:(id)sender;
- (void)addOperation:(PPPCMD)cmd;
- (void)settingRestore;
- (void)settingSave;
+ (id)shared;
- (void)setPPPStatus:(NSNumber*)num;
-(NSAttributedString *)stringFromHTML:(NSString *)html withFont:(NSFont *)font;
- (void)checkUpdate:(const NSString *)url version:(int)currVesion;
@end

![mac-pppoe](main.png)
# mac-pppoe
pppoe client for mac osx, both for Ethernet and IEEE80211(airport)
If local type(you chose Ethernet or Airport before) pppoe is exsit, the app just call it;
If not, the app create it with your choose type(Ethernet or Airport)


## Contents
1. The application icon
2. The application updates
3. Application background
4. Internationalization
5. The program logic section
6. The post-maintenance
7. Development environment
8. About quit-action Update

## detail

### 1. The application icon
PPPoEClient.icns, you can diy it yourself。
128 × 128 pixels

### 2. The application updates
I write it in pppoeGUI.

#### 2.1 constant
```objc
const NSString *curl=@"http://dev.cppfun.com/pppoe.txt";
const int ccurrVesion=1;
```
#### 2.2 function
```objc
- (void)checkUpdate:(const NSString *)url version:(int)currVesion;
```

#### 2.3 call it
I put it in the position after the success pppoe connection for backend asynchronous checks
note：
// osx can make the app with 32bit and 64bit together
// so we do need the Ostype request field on osx
// http://dev.cppfun.com/pppoe.txt?CurrVersion=1
I just implement it by response a simple string

```objc
// here do some update check
[self checkUpdate:curl version:ccurrVesion];
```

### 3. Application background img
background.jpg
Do not change the name and type. Image Size：465 × 329 pixels
You can replace the image to modify the application background.

### 4. Internationalization
both English and Chinese
Localizable.strings includes chinese and english
Note that the inside of the format (with a semicolon)：
```objc
"updateLabel" = "A new version find.";
"updateLabel" = "发现一个新版本.";
```

### 5. The program logic section
cocoa model.

### 6. The post-maintenance
I do.

### 7. Development environment

* OSX Version 10.11.1 (15B42) 64-bit；
* xcode Version 7.2 (7C68); 


### 8. About quit-action Update
just update pppoeGUI.m - (IBAction)qButtonAction:(id)sender;

```objc
- (IBAction)qButtonAction:(id)sender {
    // update for cancel begin
    if (queue) [queue cancelAllOperations];
    if (tStatus == kDisconnectTitle || tStatus == kCancelTitle) {
        [self addOperation:kPPPDisconnect];
    }
    // update for cancel endl
	[[NSApplication sharedApplication] terminate:sender];
}
```

License
-

MIT

*http://www.cppfun.com*
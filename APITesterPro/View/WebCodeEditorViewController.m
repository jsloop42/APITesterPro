//
//  WebCodeEditorViewController.m
//  APITesterPro
//
//  Created by Jaseem V V on 06.04.2024.
//  Copyright © 2024 Jaseem V V. All rights reserved.
//

#import "WebCodeEditorViewController.h"
#import "APITesterPro-Swift.h"
#import "Utils.h"

@interface WebCodeEditorViewController ()
@property (nonatomic, strong) App *app;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) NSNotificationCenter *nc;
@property (nonatomic, strong, readonly) NSString *editorTextDidChangeKey;

typedef NS_ENUM(NSInteger, WCEditorTheme) {
    WCEditorThemeLight,
    WCEditorThemeDark
};
@end

@implementation WebCodeEditorViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.app = [App shared];
        _text = @"";
        self.nc = [NSNotificationCenter defaultCenter];
        _editorTextDidChangeKey = @"editor-text-did-change";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    debug(@"webcodeeditor view did load");
    [self setupUI];
}

- (void)setupUI {
    [self.view setBackgroundColor:[self.app getBackgroundColor]];
    [self.navigationController.view setBackgroundColor:[self.app getBackgroundColor]];
    [self setupNavbar];
    [self setupWebView];
}

- (void)setupNavbar {
    self.navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    self.navBar.backgroundColor = [self.app getBackgroundColor];
    [self.view addSubview:self.navBar];
    UINavigationItem *navItem = [[UINavigationItem alloc] init];
    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelBtnDidTap)];
    UIBarButtonItem *saveBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveBtnDidTap)];
    navItem.leftBarButtonItem = cancelBtn;
    navItem.rightBarButtonItem = saveBtn;
    [self.navBar setItems:@[navItem] animated:NO];
}

- (void)setupWebView {
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:[self setupMessageHandler]];
    [self updateTheme:[self currentEditorTheme]];
    debug(@"theme dark?: %d", (long)[self.app getCurrentUIStyle] == UIUserInterfaceStyleDark);
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.webView];
    
    NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:self.webView
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.navBar
                                                                     attribute:NSLayoutAttributeBottom
                                                                    multiplier:1.0
                                                                      constant:0.0];

    NSLayoutConstraint *leadingConstraint = [NSLayoutConstraint constraintWithItem:self.webView
                                                                         attribute:NSLayoutAttributeLeading
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.view
                                                                         attribute:NSLayoutAttributeLeading
                                                                        multiplier:1.0
                                                                          constant:0.0];

    NSLayoutConstraint *trailingConstraint = [NSLayoutConstraint constraintWithItem:self.webView
                                                                          attribute:NSLayoutAttributeTrailing
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:self.view
                                                                          attribute:NSLayoutAttributeTrailing
                                                                         multiplier:1.0
                                                                           constant:0.0];
    
    NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:self.webView
                                                                        attribute:NSLayoutAttributeBottom
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self.view
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0
                                                                         constant:0.0];

    [self.view addConstraints:@[topConstraint, bottomConstraint, leadingConstraint, trailingConstraint]];
    self.webView.navigationDelegate = self;
    
    NSString *editorFile = [[NSBundle mainBundle] pathForResource:@"editor" ofType:@"html"];
    debug(@"editor file %@", editorFile);
    NSURL *htmlURL = [NSURL fileURLWithPath:editorFile];
    if (htmlURL) {
        NSURL *baseURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        [self.webView loadFileURL:htmlURL allowingReadAccessToURL:baseURL];
    } else {
        error(@"Error getting URL from editor file");
    }
}

- (WKWebViewConfiguration *)setupMessageHandler {
    NSString *script = [self userScript];
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:script injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    WKUserContentController *ctrlr = [[WKUserContentController alloc] init];
    [ctrlr addUserScript:userScript];
    [ctrlr addScriptMessageHandler:self name:@"ob"];
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = ctrlr;
    return config;
}

- (NSString *)userScript {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *url = [bundle URLForResource:@"userscript" withExtension:@"js"];
    NSString *script = @"";
    if (url) {
        NSError *err;
        script = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&err];
        if (err) {
            error(@"Error loading user script js %@", err);
        }
    }
    return script;
}

- (void)setText:(NSString *)text {
    _text = text;
    [self updateEditorText:text];
}

- (void)getEditorText:(void (^)(NSString *))completionHandler {
    WebCodeEditorViewController * __weak weakSelf = self;
    [self executeJavaScriptFn:@"ob.getText" params:nil completionHandler:^(id _Nullable result, NSError * _Nullable err) {
        if (err) {
            error(@"error getting editor content: %@", err);
            return;
        }
        NSString *text = @"";
        if ([result isKindOfClass:[NSString class]]) {
            text = (NSString *)result;
        }
        WebCodeEditorViewController *this = weakSelf;
        this->_text = text;
        [self.nc postNotificationName:self.editorTextDidChangeKey object:nil userInfo:@{@"text": text}];
        if (completionHandler) completionHandler(text);
    }];
}

/*!
 Executes the given JavaScript function with arguments in the web view
 */
- (void)executeJavaScriptFn:(NSString *)fnName params:(NSDictionary *)params completionHandler:(void (^)(id _Nullable, NSError * _Nullable))completionHandler {
    NSError *err;
    NSData *jsonData;
    if (params != nil) {
        jsonData = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:&err];
    }
    if (err) {
        error(@"JSON serialization error %@", err);
        return;
    }
    NSString *fnWithArgs;
    if (jsonData) {
        NSString *args = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        debug(@"arg-str: %@", args);
        fnWithArgs = [NSString stringWithFormat:@"%@(%@)", fnName, args];
    } else {
        fnWithArgs = [NSString stringWithFormat:@"%@()", fnName];
    }
    [self.webView evaluateJavaScript:fnWithArgs completionHandler:completionHandler];
}

- (WCEditorTheme)currentEditorTheme {
    return [self.app getCurrentUIStyle] == UIUserInterfaceStyleDark ? WCEditorThemeDark : WCEditorThemeLight;
}

- (void)updateEditorText:(NSString *)text {
    [self executeJavaScriptFn:@"ob.updateText" params:@{@"text": text} completionHandler:nil];
}

- (void)updateTheme:(WCEditorTheme)theme {
    [self executeJavaScriptFn:@"ob.updateTheme" params:@{@"mode": theme == WCEditorThemeDark ? @"dark" : @"light"} completionHandler:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    debug(@"uitrait collection did change");
    if (previousTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        debug(@"dark style");
        [self updateTheme:WCEditorThemeDark];
    } else {
        debug(@"light style");
        [self updateTheme:WCEditorThemeLight];
    }
}

#pragma mark Event handlers

- (void)cancelBtnDidTap {
    debug(@"cancel btn did tap");
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveBtnDidTap {
    debug(@"save btn did tap");
    [self getEditorText:^(NSString *text) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

#pragma mark WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    debug(@"webview loaded html");
    [self updateTheme:[self currentEditorTheme]];
    [self setText:self.text];
    [self executeJavaScriptFn:@"ob.test" params:nil completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        debug(@"result: %@", result);  // return value of the function if any
    }];
}

#pragma mark WKScriptMessageHandler

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message { 
    debug(@"wk script message received\n%@", message.body);
}

@end

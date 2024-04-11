//
//  WebCodeEditor.m
//  APITesterPro
//
//  Created by Jaseem V V on 06.04.2024.
//  Copyright © 2024 Jaseem V V. All rights reserved.
//

#import "WebCodeEditor.h"
#import "APITesterPro-Swift.h"
#import <WebKit/WebKit.h>
#import "Utils.h"

@interface WebCodeEditor ()
@property (nonatomic, strong) App *app;
@property (nonatomic, strong) WKWebView *webView;

typedef NS_ENUM(NSInteger, WCEditorTheme) {
    WCEditorThemeLight,
    WCEditorThemeDark
};
@end

@implementation WebCodeEditor

- (instancetype)init {
    self = [super init];
    if (self) {
        self.app = [App shared];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    debug(@"webcodeeditor view did load");
    [self initUI];
}

- (void)initUI {
    //[self.app updateViewBackground:self.view];
    //[self.app updateNavigationControllerBackground:self.navigationController];
    [self.view setBackgroundColor:UIColor.whiteColor];
    [self.navigationController.view setBackgroundColor:UIColor.whiteColor];
    self.webView = [[WKWebView alloc] init];
    //[self updateTheme:[self.app getCurrentUIStyle] == UIUserInterfaceStyleDark ? WCEditorThemeDark : WCEditorThemeLight];
    debug(@"theme dark?: %d", (long)[self.app getCurrentUIStyle] == UIUserInterfaceStyleDark);
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.webView];
    
    NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:self.webView
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeTop
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

- (void)executeJavaScript:(NSString *)fnName completionHandler:(void (^)(id _Nullable, NSError * _Nullable))completionHandler {
    [self.webView evaluateJavaScript:fnName completionHandler:completionHandler];
}

- (void)updateTheme:(WCEditorTheme)theme {
//    [self.webView setBackgroundColor:[self.app getBackgroundColor]];
//    NSString *fn = theme == WCEditorThemeDark ? @"changeTheme('ayu-dark')" : @"changeTheme('mdn-like')";
//    [self executeJavaScript:fn completionHandler:^(id _Nullable result, NSError * _Nullable error) {
//        debug(@"error: %@", error);
//        debug(@"result: %@", result);
//    }];
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

@end

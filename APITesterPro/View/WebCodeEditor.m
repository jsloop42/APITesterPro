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
    [self.app updateViewBackground:self.view];
    [self.app updateNavigationControllerBackground:self.navigationController];
    debug(@"webcodeeditor view did load");
    [self initUI];
}

- (void)initUI {
    self.webView = [[WKWebView alloc] init];
    [self.webView setBackgroundColor:UIColor.blackColor];  // TODO: fix
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

@end

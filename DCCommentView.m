////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  DCCommentView.m
//
//  Created by Dalton Cherry on 3/10/14.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import "DCCommentView.h"

@interface DCWatcherView : UIView

@property(nonatomic,weak)id delegate;

@end

@implementation DCWatcherView

////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)willMoveToSuperview:(UIView *)newSuperview
{
    if(self.superview) {
        [self.superview removeObserver:self.delegate forKeyPath:@"center"];
    }
    [newSuperview addObserver:self.delegate
                   forKeyPath:@"center"
                      options:0
                      context:NULL];
    [super willMoveToSuperview:newSuperview];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)dealloc
{
    [self.superview removeObserver:self.delegate forKeyPath:@"center"];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DCCommentView ()

@property(nonatomic,strong)UIView *messageBarView;
@property(nonatomic,strong)UITextView *textView;
@property(nonatomic,strong)UIButton *sendButton;
@property(nonatomic,assign)CGFloat normalHeight;
@property(nonatomic,assign)CGFloat oldSize;
@property(nonatomic,strong)UIView *backView;
@property(nonatomic,strong)UIToolbar *blurBar;
@property(nonatomic,strong)UILabel *textLabel;
@property(nonatomic,strong)UIButton *accessoryButton;
@property(nonatomic,weak)UIScrollView *scrollView;
@property(nonatomic,strong)UILabel *limitLabel;
@property(nonatomic,strong)DCWatcherView *watcherView;
@property(nonatomic,assign)BOOL hasStarted;

@end

@implementation DCCommentView

////////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithScrollView:(UIScrollView *)scrollView frame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.scrollView = scrollView;
        self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
        [self addSubview:self.scrollView];
        [self setupInit];
    }
    return self;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)setupInit
{
    self.watcherView = [[DCWatcherView alloc] initWithFrame:CGRectZero];
    self.watcherView.delegate = self;
    self.messageBarView = [[UIView alloc] init];
    self.messageBarView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.messageBarView];
    
    self.charLimit = 0;
    UIColor *color = self.tintColor;
    if(!color)
        color = [UIColor blueColor];
    self.backgroundColor = [UIColor clearColor];
    self.blurBar = [[UIToolbar alloc] init];
    self.blurBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.messageBarView addSubview:self.blurBar];
    
    self.normalHeight = 48;
    self.backView = [[UIView alloc] init];
    self.backView.backgroundColor = [UIColor whiteColor];
    self.backView.layer.cornerRadius = 8;
    self.backView.layer.borderWidth = 1;
    self.backView.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1].CGColor;
    [self.messageBarView addSubview:self.backView];
    
    self.textLabel = [[UILabel alloc] init];
    self.textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.textLabel.backgroundColor = [UIColor clearColor];
    self.textLabel.text = NSLocalizedString(@"Message", nil);
    self.textLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    [self.backView addSubview:self.textLabel];
    
    self.textView = [[UITextView alloc] init];
    self.textView.tintColor = color;
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.textView.bounces = NO;
    self.textView.delegate = (id<UITextViewDelegate>)self;
    self.textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.textView.backgroundColor = [UIColor clearColor];
    [self.backView addSubview:self.textView];
    self.textView.inputAccessoryView = self.watcherView;
    [self.textView addObserver:self forKeyPath:@"contentSize" options:(NSKeyValueObservingOptionNew) context:NULL];
    
    self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.sendButton setTitleColor:color forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor colorWithWhite:0.7 alpha:0.5] forState:UIControlStateDisabled];
    [self.sendButton setTitle:NSLocalizedString(@"Send", nil) forState:UIControlStateNormal];
    self.sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    self.sendButton.enabled = NO;
    [self.sendButton addTarget:self action:@selector(sendMessage) forControlEvents:UIControlEventTouchUpInside];
    [self.messageBarView addSubview:self.sendButton];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat textH = self.messageBarView.frame.size.height;
    if(textH == 0) {
        textH = self.normalHeight;
        self.scrollView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height-textH);
        self.messageBarView.frame = CGRectMake(0, self.scrollView.frame.origin.y+self.scrollView.frame.size.height, self.frame.size.width, textH);
    }
    self.blurBar.frame = CGRectMake(0, 0, self.messageBarView.frame.size.width, self.messageBarView.frame.size.height);
    CGFloat pad = 8;
    CGFloat btnWidth = 50;
    CGFloat left = pad;
    float tpad = 2;
    if(self.accessoryImage)
    {
        float imgWidth = 30;
        self.accessoryButton.frame = CGRectMake(pad/2, 0, imgWidth+pad, self.messageBarView.frame.size.height);
        left += self.accessoryButton.frame.size.width;
    }
    self.backView.frame = CGRectMake(left, pad, self.messageBarView.frame.size.width-(left+btnWidth+pad), self.messageBarView.frame.size.height-(pad*2));
    self.textView.frame = CGRectMake(tpad, 0, self.backView.frame.size.width-(tpad*2), self.backView.frame.size.height);
    self.textLabel.frame = CGRectMake(pad, 0, self.backView.frame.size.width-(pad*2), self.backView.frame.size.height);
    left += self.backView.frame.size.width + (pad/2);
    self.sendButton.frame = CGRectMake(left, pad, btnWidth, self.messageBarView.frame.size.height-(pad*2));
    if(self.sendButton.frame.size.height > 50 && self.charLimit > 0)
    {
        self.limitLabel.frame = CGRectMake(left-pad, (self.sendButton.frame.size.height/2)+pad, btnWidth, 18);
    }
    else
        self.limitLabel.frame = CGRectZero;
    self.oldSize = self.textView.contentSize.height;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)setTintColor:(UIColor *)tintColor
{
    [super setTintColor:tintColor];
    if(tintColor)
    {
        self.textView.tintColor = tintColor;
        [self.sendButton setTitleColor:tintColor forState:UIControlStateNormal];
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)setAccessoryImage:(UIImage *)accessoryImage
{
    _accessoryImage = accessoryImage;
    if(accessoryImage)
    {
        self.accessoryButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.accessoryButton setImage:accessoryImage forState:UIControlStateNormal];
        self.accessoryButton.showsTouchWhenHighlighted = YES;
        //self.accessoryButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.accessoryButton];
    }
    else
    {
        [self.accessoryButton removeFromSuperview];
        self.accessoryButton = nil;
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)setCharLimit:(int)charLimit
{
    _charLimit = charLimit;
    if(!self.limitLabel && self.charLimit > 0)
    {
        self.limitLabel = [[UILabel alloc] init];
        self.limitLabel.backgroundColor = [UIColor clearColor];
        self.limitLabel.textColor = [UIColor lightGrayColor];
        self.limitLabel.textAlignment = NSTextAlignmentCenter;
        self.limitLabel.font = [UIFont systemFontOfSize:15];
        [self.backView addSubview:self.limitLabel];
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)sendMessage
{
    [self.delegate didSendComment:self.textView.text];
    self.textView.text = @"";
    [self textState:@""];
    self.hasStarted = NO;
    [self setNeedsDisplay];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if([self.delegate respondsToSelector:@selector(didShowCommentView)])
        [self.delegate didShowCommentView];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidEndEditing:(UITextView *)textView
{
    if([self.delegate respondsToSelector:@selector(didDismissCommentView)])
        [self.delegate didDismissCommentView];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidChange:(UITextView *)txtView
{
    [self textState:txtView.text];
    if(txtView.text.length == 0) {
        self.hasStarted = NO;
        if([self.delegate respondsToSelector:@selector(didStopTypingComment)]) {
            [self.delegate didStopTypingComment];
        }
    } else if(txtView.text.length > 0 && !self.hasStarted) {
        self.hasStarted = YES;
        if([self.delegate respondsToSelector:@selector(didStartTypingComment)]) {
            [self.delegate didStartTypingComment];
        }
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)textState:(NSString*)text
{
    BOOL enable = NO;
    if(text.length > 0)
    {
        enable = YES;
        if(self.charLimit > 0)
        {
            if(text.length > self.charLimit)
                enable = NO;
            NSInteger left = self.charLimit-text.length;
            self.limitLabel.text = [NSString stringWithFormat:@"%ld",(long)left];
        }
    }
    self.sendButton.enabled = enable;
    if(text.length > 0)
        self.textLabel.hidden = YES;
    else
        self.textLabel.hidden = NO;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([object isKindOfClass:[UITextView class]])
    {
        UITextView *tv = object;
        float hLimit = 90;
        float yOffset = 0;
        float size = tv.contentSize.height;
        if(tv.contentSize.height > hLimit)
            size = hLimit;
        if(self.oldSize > tv.contentSize.height)
            yOffset += self.oldSize - tv.contentSize.height;
        else if([tv.text characterAtIndex:tv.text.length-1] == '\n') //this is to work around yet another bug in input accessory.
            yOffset -= tv.font.pointSize+5;
        
        CGFloat oldH = self.messageBarView.frame.size.height;
        
        CGRect frame = self.messageBarView.frame;
        frame.size.height = size+10;
        CGFloat diff = (frame.size.height-oldH);
        frame.origin.y -= diff;
        self.messageBarView.frame = frame;
        
        CGRect scrollFrame = self.scrollView.frame;
        scrollFrame.size.height -= diff;
        self.scrollView.frame = scrollFrame;
        
        [self setNeedsLayout];
        
        CGFloat topCorrect = ([tv bounds].size.height - [tv contentSize].height * [tv zoomScale])/2.0;
        if(yOffset > 0)
            topCorrect = self.textView.font.pointSize-topCorrect;
        tv.contentOffset = (CGPoint){.x = 0, .y = -topCorrect};
    } else if([object isKindOfClass:[UIView class]]) {
        UIView *view  = object;
        
        CGRect frame = self.scrollView.frame;
        frame.size.height = view.frame.origin.y - self.messageBarView.frame.size.height;
        self.scrollView.frame = frame;
        
        frame = self.messageBarView.frame;
        frame.origin.y = self.scrollView.frame.size.height + self.scrollView.frame.origin.y;
        self.messageBarView.frame = frame;
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)keyboardDidShow:(NSNotification *)aNotification
{
    [self.scrollView scrollRectToVisible:CGRectMake(0.0,
                                                    self.scrollView.contentSize.height - 1.0,
                                                    1.0,
                                                    1.0)
                                animated:YES];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)dealloc
{
    self.textView.inputAccessoryView = nil;
    [self.textView removeObserver:self forKeyPath:@"contentSize"];
}
////////////////////////////////////////////////////////////////////////////////////////////////////

@end

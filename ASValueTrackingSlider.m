//
//  ASValueTrackingSlider.m
//  ValueTrackingSlider
//
//  Created by Alan Skipp on 19/10/2013.
//  Copyright (c) 2013 Alan Skipp. All rights reserved.
//

#import "ASValueTrackingSlider.h"

#define ARROW_LENGTH 13

@interface ASValuePopUpView : UIView
- (void)setString:(NSAttributedString *)string;
- (void)setPopUpViewColour:(UIColor *)color;
@end

@implementation ASValuePopUpView
{
    CAShapeLayer *_backgroundLayer;
    CATextLayer *_textLayer;
    CGSize _oldSize;
    CGFloat _arrowCenterOffset;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        _backgroundLayer = [CAShapeLayer layer];
        _backgroundLayer.anchorPoint = CGPointMake(0, 0);
        
        _textLayer = [CATextLayer layer];
        _textLayer.alignmentMode = kCAAlignmentCenter;
        _textLayer.anchorPoint = CGPointMake(0, 0);
        _textLayer.contentsScale = [UIScreen mainScreen].scale;
        _textLayer.actions = @{@"bounds" : [NSNull null]}; // prevent implicit animation of bounds

        [self.layer addSublayer:_backgroundLayer];
        [self.layer addSublayer:_textLayer];
    }
    return self;
}

- (void)setString:(NSAttributedString *)string
{
    _textLayer.string = string;
}

- (void)setPopUpViewColour:(UIColor *)color;
{
    _backgroundLayer.fillColor = color.CGColor;
}

- (void)setArrowCenterOffset:(CGFloat)offset
{
    // only redraw if the offset has changed
    if (_arrowCenterOffset != offset) {
        _arrowCenterOffset = offset;
        [self drawPath];
    }
}

- (void)drawPath
{
    // Create rounded rect
    CGRect roundedRect = self.bounds;
    roundedRect.size.height -= ARROW_LENGTH;
    UIBezierPath *roundedRectPath = [UIBezierPath bezierPathWithRoundedRect:roundedRect cornerRadius:4.0];
    
    // Create arrow path
    UIBezierPath *arrowPath = [UIBezierPath bezierPath];
    CGFloat arrowX = CGRectGetMidX(self.bounds) + _arrowCenterOffset;
    CGPoint p0 = CGPointMake(arrowX, CGRectGetMaxY(self.bounds));
    [arrowPath moveToPoint:p0];
    [arrowPath addLineToPoint:CGPointMake((arrowX - 6.0), CGRectGetMaxY(roundedRect))];
    [arrowPath addLineToPoint:CGPointMake((arrowX + 6.0), CGRectGetMaxY(roundedRect))];
    [arrowPath closePath];
    
    // combine arrow path and rounded rect
    [roundedRectPath appendPath:arrowPath];

    _backgroundLayer.path = roundedRectPath.CGPath;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // only redraw if the view size has changed
    if (!CGSizeEqualToSize(self.bounds.size, _oldSize)) {
        _textLayer.bounds = self.bounds;
        _backgroundLayer.bounds = self.bounds;
        [self drawPath];
        _oldSize = self.bounds.size;
    }
}

@end


@interface ASValueTrackingSlider()
@property (strong, nonatomic) NSNumberFormatter *numberFormatter;
@property (strong, nonatomic) ASValuePopUpView *popUpView;
@property (readonly, nonatomic) CGRect thumbRect;
@property (strong, nonatomic) NSMutableAttributedString *attributedString;
@end

#define MIN_POPUPVIEW_WIDTH 36.0
#define POPUPVIEW_WIDTH_INSET 10.0

@implementation ASValueTrackingSlider
{
    CGFloat _popUpViewWidth;
    CGFloat _popUpViewHeight;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self setup];
    }
    return self;
}

#pragma mark - public methods

- (void)setTextColor:(UIColor *)color
{
    _textColor = color;
    [self.attributedString addAttribute:NSForegroundColorAttributeName
                                  value:(id)color.CGColor
                                  range:NSMakeRange(0, [_attributedString length])];
}

- (void)setPopUpViewColor:(UIColor *)color;
{
    _popUpViewColor = color;
    [self.popUpView setPopUpViewColour:color];
}

// when either the max value or number formatter changes, recalculate the popUpView width
- (void)setMaximumValue:(float)maximumValue
{
    [super setMaximumValue:maximumValue];
    [self calculateMinPopUpViewWidth];
}

- (void)setNumberFormatter:(NSNumberFormatter *)numberFormatter
{
    _numberFormatter = numberFormatter;
    [self calculateMinPopUpViewWidth];
}

// set max and min digits to same value to keep string length consistent
- (void)setMaxFractionDigitsDisplayed:(NSUInteger)maxDigits;
{
    [self.numberFormatter setMaximumFractionDigits:maxDigits];
    [self.numberFormatter setMinimumFractionDigits:maxDigits];
    [self calculateMinPopUpViewWidth];
}

#pragma mark - private methods

- (void)setup
{
    _popUpViewHeight = 40.0;
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setRoundingMode:NSNumberFormatterRoundHalfUp];
    self.numberFormatter = formatter;
    [self setMaxFractionDigitsDisplayed:2];
    
    self.popUpView = [[ASValuePopUpView alloc] initWithFrame:CGRectZero];
    self.popUpView.alpha = 0.0;
    [self addSubview:self.popUpView];
    
    self.attributedString = [[NSMutableAttributedString alloc] initWithString:@" "
                                                                   attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:22.0f]}];
    self.textColor = [UIColor whiteColor];
    self.popUpViewColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    
    [self calculateMinPopUpViewWidth];
}

- (void)showPopUp
{
    self.popUpView.transform = CGAffineTransformMakeScale(0.25, 0.25);
    self.popUpView.alpha = 1.0;
    
    [UIView  animateWithDuration:0.5
                           delay:0
          usingSpringWithDamping:0.4
           initialSpringVelocity:0.5
                         options:UIViewAnimationOptionCurveLinear
                      animations:^{
                          self.popUpView.transform = CGAffineTransformIdentity;
                      } completion:nil];
}

- (void)hidePopUp
{
    [UIView animateWithDuration:0.5 animations:^{
        self.popUpView.alpha = 0.0;
    }];
}

- (void)positionAndUpdatePopUpView
{
    NSString *string = [_numberFormatter stringFromNumber:@(self.value)];
    [[self.attributedString mutableString] setString:string];
    
    CGRect thumbRect = self.thumbRect;
    CGFloat thumbW = thumbRect.size.width;
    CGFloat thumbH = thumbRect.size.height;

    CGRect popUpRect = CGRectInset(thumbRect, (thumbW - _popUpViewWidth - POPUPVIEW_WIDTH_INSET)/2, (thumbH -_popUpViewHeight)/2);
    popUpRect.origin.y = thumbRect.origin.y - _popUpViewHeight;
    
    // determine if popUpRect extends beyond the frame of the UISlider
    // if so adjust frame and set the center offset of the PopUpView's arrow
    CGFloat minOffsetX = CGRectGetMinX(popUpRect);
    CGFloat maxOffsetX = CGRectGetMaxX(popUpRect) - self.bounds.size.width;
    
    if (minOffsetX < 0.0) {
        popUpRect.origin.x -= minOffsetX;
        [self.popUpView setArrowCenterOffset:minOffsetX];
    }
    else if (maxOffsetX > 0.0) {
        popUpRect.origin.x -= maxOffsetX;
        [self.popUpView setArrowCenterOffset:maxOffsetX];
    }
    else {
        [self.popUpView setArrowCenterOffset:0.0];
    }
    
    self.popUpView.frame = popUpRect;
    [self.popUpView setString:self.attributedString];
}

- (void)calculateMinPopUpViewWidth
{
    NSString *string = [_numberFormatter stringFromNumber:@(self.maximumValue)];
    [[self.attributedString mutableString] setString:string];
    _popUpViewWidth = ceilf(MAX([self.attributedString size].width, MIN_POPUPVIEW_WIDTH));
}

- (CGRect)thumbRect
{
    return [self thumbRectForBounds:self.bounds
                          trackRect:[self trackRectForBounds:self.bounds]
                              value:self.value];
}

#pragma mark - subclassed methods

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    BOOL begin = [super beginTrackingWithTouch:touch withEvent:event];
    if (begin) {
        [self positionAndUpdatePopUpView];
        [self showPopUp];
    }
    return begin;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    BOOL continueTrack = [super continueTrackingWithTouch:touch withEvent:event];
    if (continueTrack) [self positionAndUpdatePopUpView];
    return continueTrack;
}

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    [super cancelTrackingWithEvent:event];
    [self hidePopUp];
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    [super endTrackingWithTouch:touch withEvent:event];
    [self hidePopUp];
}

@end

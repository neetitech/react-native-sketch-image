//
//  TriangleEntity.m
//  RNImageEditor
//
//  Created by Thomas Steinbrüchel on 30.10.18.
//  Copyright © 2018 Terry. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PathEntity.h"

@implementation PathEntity
{
    CGContextRef _drawingContext, _translucentDrawingContext;
    RNImageEditorData *_currentPath;
    NSMutableArray *_paths;
}

- (instancetype)initAndSetupWithParent: (NSInteger)parentWidth
                          parentHeight: (NSInteger)parentHeight
                                 width: (NSInteger)width
                                height: (NSInteger)height
                     entityStrokeWidth: (CGFloat)entityStrokeWidth
                     entityStrokeColor: (UIColor *)entityStrokeColor{
    self = [super initWithFrame:CGRectMake(0, 0, width, height)];
    
    if (self) {
        _paths = [NSMutableArray new];
        __needsFullRedraw = YES;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}


- (void)createDrawingContext {
    CGFloat scale = self.window.screen.scale;
    CGSize size = self.bounds.size;
    size.width *= scale;
    size.height *= scale;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    _drawingContext = CGBitmapContextCreate(nil, size.width, size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    _translucentDrawingContext = CGBitmapContextCreate(nil, size.width, size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);

    CGContextConcatCTM(_drawingContext, CGAffineTransformMakeScale(scale, scale));
    CGContextConcatCTM(_translucentDrawingContext, CGAffineTransformMakeScale(scale, scale));
}

- (void)setFrozenImageNeedsUpdate {
    CGImageRelease(_frozenImage);
    CGImageRelease(_translucentFrozenImage);
    _frozenImage = nil;
    _translucentFrozenImage = nil;
}

- (void)dealloc {
    CGContextRelease(_drawingContext);
    _drawingContext = nil;
    CGImageRelease(_frozenImage);
    _frozenImage = nil;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGRect bounds = self.bounds;

    if (__needsFullRedraw) {
        [self setFrozenImageNeedsUpdate];
        CGContextClearRect(_drawingContext, bounds);
        for (RNImageEditorData *path in _paths) {
            [path drawInContext:_drawingContext];
        }
        __needsFullRedraw = NO;
    }

    if (!_frozenImage) {
        _frozenImage = CGBitmapContextCreateImage(_drawingContext);
    }
    
    if (!_translucentFrozenImage && _currentPath.isTranslucent) {
        _translucentFrozenImage = CGBitmapContextCreateImage(_translucentDrawingContext);
    }

    if (_frozenImage) {
        NSLog(@"Frozen Image");
        CGContextDrawImage(context, bounds, _frozenImage);
        
        // Need to think
    }

    if (_translucentFrozenImage && _currentPath.isTranslucent) {
        CGContextDrawImage(context, bounds, _translucentFrozenImage);
    }
}

- (void)newPath {
    NSLog(@"Drawing in path entity");
    [self.pathList addObject: self.activePath];
}

- (void) addPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth points:(NSArray*) points {
    if (CGColorGetComponents(strokeColor.CGColor)[3] != 0.0) {
        self.entityStrokeColor = strokeColor;
    }
    
    bool exist = false;
    for(int i=0; i<_paths.count; i++) {
        if (((RNImageEditorData*)_paths[i]).pathId == pathId) {
            exist = true;
            break;
        }
    }
    
    if (!exist) {
        RNImageEditorData *data = [[RNImageEditorData alloc] initWithId: pathId
                                                  strokeColor: strokeColor
                                                  strokeWidth: strokeWidth
                                                       points: points];
        [_paths addObject: data];
        [data drawInContext:_drawingContext];
        [self setFrozenImageNeedsUpdate];
        [self setNeedsDisplay];
    }
}

- (void)deletePath:(int) pathId{
    int index = -1;
    for(int i=0; i<_paths.count; i++) {
        if (((RNImageEditorData*)_paths[i]).pathId == pathId) {
            index = i;
            break;
        }
    }
    
    if (index > -1) {
        [_paths removeObjectAtIndex: index];
        __needsFullRedraw = YES;
        [self setNeedsDisplay];
        if(_delegate!=nil){
            [_delegate notifyPathsUpdate:_paths.count];
        }
    }
}

- (void)addPointX:(float)x Y: (float)y {
    CGPoint newPoint = CGPointMake(x, y);
    CGRect updateRect = [_currentPath addPoint: newPoint];
    // above two lines needs to remove
    
    if (_currentPath.isTranslucent) {
        CGContextClearRect(_translucentDrawingContext, self.bounds);
        [_currentPath drawInContext:_translucentDrawingContext];
    } else {
        [_currentPath drawLastPointInContext:_drawingContext];
    }
    
    [self setFrozenImageNeedsUpdate];
    [self setNeedsDisplayInRect:updateRect];
}

- (void)newPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth {
    if (CGColorGetComponents(strokeColor.CGColor)[3] != 0.0) {
        self.entityStrokeColor = strokeColor;
    }
    self.entityStrokeWidth = strokeWidth;
    
    _currentPath = [[RNImageEditorData alloc]
                    initWithId: pathId
                    strokeColor: strokeColor
                    strokeWidth: strokeWidth];
    
    [_paths addObject: _currentPath];
}

- (void)endPath {
    NSLog(@"end Path");
    if (_currentPath.isTranslucent) {
        [_currentPath drawInContext:_drawingContext];
    }
    _currentPath = nil;
    if(_delegate!=nil){
        [_delegate notifyPathsUpdate:_paths.count];
    }
}

- (void) clear{
    [_paths removeAllObjects];
    _currentPath = nil;
    __needsFullRedraw = YES;
    [self setNeedsDisplay];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGContextRelease(_drawingContext);
    _drawingContext = nil;
    [self createDrawingContext];
    __needsFullRedraw = YES;
    [self setNeedsDisplay];
    
}

@end

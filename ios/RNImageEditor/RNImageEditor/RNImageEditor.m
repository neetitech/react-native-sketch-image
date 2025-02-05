#import "RNImageEditorManager.h"
#import "RNImageEditor.h"
#import "RNImageEditorData.h"
#import <React/RCTEventDispatcher.h>
#import <React/RCTView.h>
#import <React/UIView+React.h>
#import "RNImageEditorUtility.h"
#import "BackgroundText.h"
#import "entities/base/Enumerations.h"
#import "entities/base/MotionEntity.h"
#import "entities/CircleEntity.h"
#import "entities/RectEntity.h"
#import "entities/TriangleEntity.h"
#import "entities/ArrowEntity.h"
#import "entities/TextEntity.h"
#import "entities/PathEntity.h"

@implementation RNImageEditor
{
    RCTEventDispatcher *_eventDispatcher;
    PathEntity *_pathEntity;
    NSUInteger pathDrawingIndex;
    CGSize _lastSize;

    UIImage *_backgroundImage;
    UIImage *_backgroundImageScaled;
    NSString *_backgroundImageContentMode;
    
    NSArray *_arrTextOnSketch, *_arrSketchOnText;
}

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
    self = [super init];
    if (self) {
        _eventDispatcher = eventDispatcher;
        self.motionEntities = [NSMutableArray new];
        //[self addPathLayer];

        self.backgroundColor = [UIColor clearColor];
        self.clearsContextBeforeDrawing = YES;
        
        self.selectedEntity = nil;
        self.entityBorderColor = [UIColor clearColor];
        self.entityBorderStyle = DASHED;
        self.entityBorderStrokeWidth = 1.0;
        self.entityStrokeWidth = 5.0;
        self.entityStrokeColor = [UIColor blackColor];
        
        self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        self.tapGesture.delegate = self;
        self.tapGesture.numberOfTapsRequired = 1;
        
        self.rotateGesture = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotate:)];
        self.rotateGesture.delegate = self;
        
        self.moveGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMove:)];
        self.moveGesture.delegate = self;
        self.moveGesture.minimumNumberOfTouches = 1;
        self.moveGesture.maximumNumberOfTouches = 1;
        
        self.scaleGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handleScale:)];
        self.scaleGesture.delegate = self;
        
        [self addGestureRecognizer:self.tapGesture];
        [self addGestureRecognizer:self.rotateGesture];
        [self addGestureRecognizer:self.moveGesture];
        [self addGestureRecognizer:self.scaleGesture];
        
    }
    return self;
}


// Make multiple GestureRecognizers work
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return TRUE;
}

- (void)drawRect:(CGRect)rect {

    CGRect bounds = self.bounds;
    [_pathEntity drawRect:rect];
    if (_backgroundImage) {
        if (!_backgroundImageScaled) {
            _backgroundImageScaled = [self scaleImage:_backgroundImage toSize:bounds.size contentMode: _backgroundImageContentMode];
        }

        [_backgroundImageScaled drawInRect:bounds];
    }

    for (BackgroundText *text in _arrSketchOnText) {
        [text.text drawInRect: text.drawRect withAttributes: text.attribute];
    }
    
    for (BackgroundText *text in _arrTextOnSketch) {
        [text.text drawInRect: text.drawRect withAttributes: text.attribute];
    }
    
    int counter = 0;
    BOOL isPathDrawingAdded = false;
    for (MotionEntity *entity in self.motionEntities) {
        if(counter == 0){
            NSLog(@"inside motion loop:: %lu", (unsigned long)self.motionEntities.count);
            [_pathEntity removeFromSuperview];
        }
        [entity updateStrokeSettings:self.entityBorderStyle
                   borderStrokeWidth:self.entityBorderStrokeWidth
                   borderStrokeColor:self.entityBorderColor
                   entityStrokeWidth:self.entityStrokeWidth
                   entityStrokeColor:self.entityStrokeColor];
        
        if ([entity isSelected]) {
            [entity setNeedsDisplay];
        }
        if(pathDrawingIndex == counter){
            isPathDrawingAdded = true;
            NSLog(@"inside motion loop add subview");
            [self addSubview:_pathEntity];
        }
        [self addSubview:entity];
        counter++;
    }
    
    
    if(isPathDrawingAdded == false && self.motionEntities.count>0){
        [self addSubview:_pathEntity];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (!CGSizeEqualToSize(self.bounds.size, _lastSize)) {

        _lastSize = self.bounds.size;
        [self addPathLayer];
        _backgroundImageScaled = nil;
        
        for (BackgroundText *text in [_arrTextOnSketch arrayByAddingObjectsFromArray: _arrSketchOnText]) {
            CGPoint position = text.position;
            if (!text.isAbsoluteCoordinate) {
                position.x *= self.bounds.size.width;
                position.y *= self.bounds.size.height;
            }
            position.x -= text.drawRect.size.width * text.anchor.x;
            position.y -= text.drawRect.size.height * text.anchor.y;
            text.drawRect = CGRectMake(position.x, position.y, text.drawRect.size.width, text.drawRect.size.height);
        }
        
        [self setNeedsDisplay];
    }
}

- (BOOL)openSketchFile:(NSString *)filename directory:(NSString*) directory contentMode:(NSString*)mode {
    if (filename) {
        UIImage *image = [UIImage imageWithContentsOfFile: [directory stringByAppendingPathComponent: filename]];
        image = image ? image : [UIImage imageNamed: filename];
        if(image) {
            if (image.imageOrientation != UIImageOrientationUp) {
                UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
                [image drawInRect:(CGRect){0, 0, image.size}];
                UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                image = normalizedImage;
            }
            _backgroundImage = image;
            _backgroundImageScaled = nil;
            _backgroundImageContentMode = mode;
            [self setNeedsDisplay];

            return YES;
        }
    }
    return NO;
}

- (void)setCanvasText:(NSArray *)aText {
    NSMutableArray *arrTextOnSketch = [NSMutableArray new];
    NSMutableArray *arrSketchOnText = [NSMutableArray new];
    NSDictionary *alignments = @{
                                 @"Left": [NSNumber numberWithInteger:NSTextAlignmentLeft],
                                 @"Center": [NSNumber numberWithInteger:NSTextAlignmentCenter],
                                 @"Right": [NSNumber numberWithInteger:NSTextAlignmentRight]
                                 };
    
    for (NSDictionary *property in aText) {
        if (property[@"text"]) {
            NSMutableArray *arr = [@"TextOnSketch" isEqualToString: property[@"overlay"]] ? arrTextOnSketch : arrSketchOnText;
            BackgroundText *text = [BackgroundText new];
            text.text = property[@"text"];
            UIFont *font = nil;
            if (property[@"font"]) {
                font = [UIFont fontWithName: property[@"font"] size: property[@"fontSize"] == nil ? 12 : [property[@"fontSize"] floatValue]];
                font = font == nil ? [UIFont systemFontOfSize: property[@"fontSize"] == nil ? 12 : [property[@"fontSize"] floatValue]] : font;
            } else if (property[@"fontSize"]) {
                font = [UIFont systemFontOfSize: [property[@"fontSize"] floatValue]];
            } else {
                font = [UIFont systemFontOfSize: 12];
            }
            text.font = font;
            text.anchor = property[@"anchor"] == nil ?
                CGPointMake(0, 0) :
                CGPointMake([property[@"anchor"][@"x"] floatValue], [property[@"anchor"][@"y"] floatValue]);
            text.position = property[@"position"] == nil ?
                CGPointMake(0, 0) :
                CGPointMake([property[@"position"][@"x"] floatValue], [property[@"position"][@"y"] floatValue]);
            long color = property[@"fontColor"] == nil ? 0xFF000000 : [property[@"fontColor"] longValue];
            UIColor *fontColor =
            [UIColor colorWithRed:(CGFloat)((color & 0x00FF0000) >> 16) / 0xFF
                            green:(CGFloat)((color & 0x0000FF00) >> 8) / 0xFF
                             blue:(CGFloat)((color & 0x000000FF)) / 0xFF
                            alpha:(CGFloat)((color & 0xFF000000) >> 24) / 0xFF];
            NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
            NSString *a = property[@"alignment"] ? property[@"alignment"] : @"Left";
            style.alignment = [alignments[a] integerValue];
            style.lineHeightMultiple = property[@"lineHeightMultiple"] ? [property[@"lineHeightMultiple"] floatValue] : 1.0;
            text.attribute = @{
                               NSFontAttributeName:font,
                               NSForegroundColorAttributeName:fontColor,
                               NSParagraphStyleAttributeName:style
                               };
            text.isAbsoluteCoordinate = ![@"Ratio" isEqualToString:property[@"coordinate"]];
            CGSize textSize = [text.text sizeWithAttributes:text.attribute];
            
            CGPoint position = text.position;
            if (!text.isAbsoluteCoordinate) {
                position.x *= self.bounds.size.width;
                position.y *= self.bounds.size.height;
            }
            position.x -= textSize.width * text.anchor.x;
            position.y -= textSize.height * text.anchor.y;
            text.drawRect = CGRectMake(position.x, position.y, textSize.width, textSize.height);
            [arr addObject: text];
        }
    }
    _arrTextOnSketch = [arrTextOnSketch copy];
    _arrSketchOnText = [arrSketchOnText copy];
    [self setNeedsDisplay];
}

-(void) addPathLayer{
    if(self->_pathEntity){
        return;
    }
    CGFloat scale = self.window.screen.scale;
    CGSize size = self.bounds.size;
    size.width *= scale;
    size.height *= scale;
    pathDrawingIndex = 0;
    
    PathEntity *entity = [[PathEntity alloc]
                          initAndSetupWithParent:self.bounds.size.width
                          parentHeight:self.bounds.size.height
                          width:size.width
                          height:size.height
                          entityStrokeWidth:self.entityStrokeWidth
                          entityStrokeColor:self.entityStrokeColor];
    
    [self addSubview:entity];
    self->_pathEntity = entity;
    _pathEntity._needsFullRedraw = YES;
    _pathEntity.delegate = self;
}

- (void)newPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth {
    NSLog(@"new Path");
    
    [_pathEntity newPath:pathId strokeColor:strokeColor strokeWidth:strokeWidth];
    
    if (CGColorGetComponents(strokeColor.CGColor)[3] != 0.0) {
        self.entityStrokeColor = strokeColor;
    }
    self.entityStrokeWidth = strokeWidth;
}

- (void) addPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth points:(NSArray*) points {
    NSLog(@"add Path");
    if (CGColorGetComponents(strokeColor.CGColor)[3] != 0.0) {
        self.entityStrokeColor = strokeColor;
    }
    [_pathEntity addPath:pathId strokeColor:strokeColor strokeWidth:strokeWidth points:points];
}

- (void)deletePath:(int) pathId {
    [_pathEntity deletePath:pathId];
}

- (void)addPointX: (float)x Y: (float)y isMove:(BOOL)isMove {
    NSLog(@"Add Point");
    if (!self.selectedEntity && (![self findEntityAtPointX:x andY:y] || isMove)) {
        if (self->_pathEntity) {
            [_pathEntity addPointX:x Y:y];
        }
    }
}

- (void)endPath {
    NSLog(@"end Path");
    if (self->_pathEntity) {
        [_pathEntity endPath];
    }
}

- (void) clear {
    if (self->_pathEntity) {
        [_pathEntity clear];
    }
    [self setNeedsDisplay];
}

- (void) layerUpdate: (BOOL) isUp {
    if(self.selectedEntity){
        NSUInteger currentIndex = [self.subviews indexOfObject:self.selectedEntity];
        NSUInteger updateIndex =  isUp? currentIndex + 1 : currentIndex - 1;
        [self exchangeSubviewAtIndex:currentIndex withSubviewAtIndex:updateIndex];
        
        if(updateIndex < self.motionEntities.count && currentIndex < self.motionEntities.count){
            [self.motionEntities exchangeObjectAtIndex:currentIndex withObjectAtIndex:updateIndex];
        }
        pathDrawingIndex = [self.subviews indexOfObject:_pathEntity];
        
    }
    
}

-(void) drawPathDrawingInContext:(CGContextRef)context withScaleFactor:(CGFloat)scaleFactor{
    CGContextSaveGState(context);
    
    // Scale shapes because we cropToImageSize
    if(scaleFactor!=-1.0f){
        CGContextScaleCTM(context, scaleFactor, scaleFactor);
    }
    
    // Center the context around the view's anchor point
    CGContextTranslateCTM(context, [_pathEntity center].x, [_pathEntity center].y);
    
    // Apply the view's transform about the anchor point
    CGContextConcatCTM(context, [_pathEntity transform]);
    
    // Offset by the portion of the bounds left of and above the anchor point
    CGContextTranslateCTM(context, -[_pathEntity bounds].size.width * [[_pathEntity layer] anchorPoint].x, -[_pathEntity bounds].size.height * [[_pathEntity layer] anchorPoint].y);
    
    // Render the entity
    [_pathEntity.layer renderInContext:context];
    
    CGContextRestoreGState(context);
}

- (UIImage*)createImageWithTransparentBackground: (BOOL) transparent includeImage:(BOOL)includeImage includeText:(BOOL)includeText cropToImageSize:(BOOL)cropToImageSize {
    if (_backgroundImage && cropToImageSize) {
        CGRect rect = CGRectMake(0, 0, _backgroundImage.size.width, _backgroundImage.size.height);
        UIGraphicsBeginImageContextWithOptions(rect.size, !transparent, 1);
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (!transparent) {
            CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
            CGContextFillRect(context, rect);
        }
        CGRect targetRect = [RNImageEditorUtility fillImageWithSize:self.bounds.size toSize:rect.size contentMode:@"AspectFill"];
        CGFloat scaleFactor = [RNImageEditorUtility getScaleDifference:self.bounds.size toSize:rect.size contentMode:@"AspectFill"];
        if (includeImage) {
            [_backgroundImage drawInRect:rect];
        }
        
        if (includeText) {
            for (BackgroundText *text in _arrSketchOnText) {
                [text.text drawInRect: text.drawRect withAttributes: text.attribute];
            }
        }
        
        CGContextDrawImage(context, targetRect, _pathEntity.frozenImage);
        CGContextDrawImage(context, targetRect, _pathEntity.translucentFrozenImage);
        
        if (includeText) {
            for (BackgroundText *text in _arrTextOnSketch) {
                [text.text drawInRect: text.drawRect withAttributes: text.attribute];
            }
        }
        
        int counter = 0;
        BOOL isPathDrawingAdded = false;
        for (MotionEntity *entity in self.motionEntities) {
            
            if(counter == pathDrawingIndex){
                [self drawPathDrawingInContext:context withScaleFactor:scaleFactor];
                isPathDrawingAdded = true;
            }
            
            CGContextSaveGState(context);
            
            // Scale shapes because we cropToImageSize
            CGContextScaleCTM(context, scaleFactor, scaleFactor);
            
            // Center the context around the view's anchor point
            CGContextTranslateCTM(context, [entity center].x, [entity center].y);
            
            // Apply the view's transform about the anchor point
            CGContextConcatCTM(context, [entity transform]);
            
            // Offset by the portion of the bounds left of and above the anchor point
            CGContextTranslateCTM(context, -[entity bounds].size.width * [[entity layer] anchorPoint].x, -[entity bounds].size.height * [[entity layer] anchorPoint].y);
            
            // Render the entity
            [entity.layer renderInContext:context];
            
            CGContextRestoreGState(context);
            counter++;
        }
        
        if(isPathDrawingAdded == false){
            [self drawPathDrawingInContext:context withScaleFactor:scaleFactor];
        }
        
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return img;
    } else {
        CGRect rect = self.bounds;
        UIGraphicsBeginImageContextWithOptions(rect.size, !transparent, 0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (!transparent) {
            CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
            CGContextFillRect(context, rect);
        }
        if (_backgroundImage && includeImage) {
            CGRect targetRect = [RNImageEditorUtility fillImageWithSize:_backgroundImage.size toSize:rect.size contentMode:_backgroundImageContentMode];
            [_backgroundImage drawInRect:targetRect];
        }
        
        if (includeText) {
            for (BackgroundText *text in _arrSketchOnText) {
                [text.text drawInRect: text.drawRect withAttributes: text.attribute];
            }
        }
        
        CGContextDrawImage(context, rect, _pathEntity.frozenImage);
        CGContextDrawImage(context, rect, _pathEntity.translucentFrozenImage);
        
        if (includeText) {
            for (BackgroundText *text in _arrTextOnSketch) {
                [text.text drawInRect: text.drawRect withAttributes: text.attribute];
            }
        }
        int counter = 0;
        BOOL isPathDrawingAdded = false;
        for (MotionEntity *entity in self.motionEntities) {
            if(counter == pathDrawingIndex){
                [self drawPathDrawingInContext:context withScaleFactor:-1.0f];
                isPathDrawingAdded = true;
            }
            CGContextSaveGState(context);
            
            // Center the context around the view's anchor point
            CGContextTranslateCTM(context, [entity center].x, [entity center].y);
            
            // Apply the view's transform about the anchor point
            CGContextConcatCTM(context, [entity transform]);
            
            // Offset by the portion of the bounds left of and above the anchor point
            CGContextTranslateCTM(context, -[entity bounds].size.width * [[entity layer] anchorPoint].x, -[entity bounds].size.height * [[entity layer] anchorPoint].y);
            
            // Render the entity
            [entity.layer renderInContext:context];
            
            CGContextRestoreGState(context);
        }
        if(isPathDrawingAdded == false){
            [self drawPathDrawingInContext:context withScaleFactor:-1.0f];
        }
        
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return img;
    }
}

- (void)saveImageOfType:(NSString*) type folder:(NSString*) folder filename:(NSString*) filename withTransparentBackground:(BOOL) transparent includeImage:(BOOL)includeImage includeText:(BOOL)includeText cropToImageSize:(BOOL)cropToImageSize {
    UIImage *img = [self createImageWithTransparentBackground:transparent includeImage:includeImage includeText:(BOOL)includeText cropToImageSize:cropToImageSize];
    
    if (folder != nil && filename != nil) {
        NSURL *tempDir = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent: folder];
        NSError * error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:[tempDir path]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error == nil) {
            NSURL *fileURL = [[tempDir URLByAppendingPathComponent: filename] URLByAppendingPathExtension: type];
            NSData *imageData = [self getImageData:img type:type];
            [imageData writeToURL:fileURL atomically:YES];

            if (_onChange) {
                _onChange(@{ @"success": @YES, @"path": [fileURL path]});
            }
        } else {
            if (_onChange) {
                _onChange(@{ @"success": @NO, @"path": [NSNull null]});
            }
        }
    } else {
        if ([type isEqualToString: @"png"]) {
            img = [UIImage imageWithData: UIImagePNGRepresentation(img)];
        }
        UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }
}

- (UIImage *)scaleImage:(UIImage *)originalImage toSize:(CGSize)size contentMode: (NSString*)mode
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextClearRect(context, CGRectMake(0, 0, size.width, size.height));

    CGRect targetRect = [RNImageEditorUtility fillImageWithSize:originalImage.size toSize:size contentMode:mode];
    CGContextDrawImage(context, targetRect, originalImage.CGImage);
    
    CGImageRef scaledImage = CGBitmapContextCreateImage(context);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    UIImage *image = [UIImage imageWithCGImage:scaledImage];
    CGImageRelease(scaledImage);
    
    return image;
}

- (NSString*) transferToBase64OfType: (NSString*) type withTransparentBackground: (BOOL) transparent includeImage:(BOOL)includeImage includeText:(BOOL)includeText cropToImageSize:(BOOL)cropToImageSize {
    UIImage *img = [self createImageWithTransparentBackground:transparent includeImage:includeImage includeText:(BOOL)includeText cropToImageSize:cropToImageSize];
    NSData *data = [self getImageData:img type:type];
    return [data base64EncodedStringWithOptions: NSDataBase64Encoding64CharacterLineLength];
}

- (NSData*)getImageData:(UIImage*)img type:(NSString*) type {
    NSData *data;
    if ([type isEqualToString: @"jpg"]) {
        data = UIImageJPEGRepresentation(img, 0.9);
    } else {
        data = UIImagePNGRepresentation(img);
    }
    return data;
}

#pragma mark - MotionEntites related code
- (void)setShapeConfiguration:(NSDictionary *)dict {
    if (![dict[@"shapeBorderColor"] isEqual:[NSNull null]]) {
        long shapeBorderColorLong = [dict[@"shapeBorderColor"] longValue];
        UIColor *shapeBorderColor = [UIColor colorWithRed:(CGFloat)((shapeBorderColorLong & 0x00FF0000) >> 16) / 0xFF
                                                    green:(CGFloat)((shapeBorderColorLong & 0x0000FF00) >> 8) / 0xFF
                                                     blue:(CGFloat)((shapeBorderColorLong & 0x000000FF)) / 0xFF
                                                    alpha:(CGFloat)((shapeBorderColorLong & 0xFF000000) >> 24) / 0xFF];
        if (CGColorGetComponents(shapeBorderColor.CGColor)[3] != 0.0) {
            self.entityBorderColor = shapeBorderColor;
        }
    }
    
    if (![dict[@"shapeBorderStyle"] isEqual:[NSNull null]]) {
        NSString *borderStyle = dict[@"shapeBorderStyle"];
        switch ([@[@"Dashed", @"Solid"] indexOfObject: borderStyle]) {
            case 0:
                self.entityBorderStyle = DASHED;
                break;
            case 1:
                self.entityBorderStyle = SOLID;
            case NSNotFound:
            default: {
                self.entityBorderStyle = DASHED;
                break;
            }
        }
    }
    
    if (![dict[@"shapeBorderStrokeWidth"] isEqual:[NSNull null]]) {
        self.entityBorderStrokeWidth = [dict[@"shapeBorderStrokeWidth"] doubleValue];
    }
    
    if (![dict[@"shapeColor"] isEqual:[NSNull null]]) {
        long shapeColorLong = [dict[@"shapeColor"] longValue];
        UIColor *shapeColor = [UIColor colorWithRed:(CGFloat)((shapeColorLong & 0x00FF0000) >> 16) / 0xFF
                                              green:(CGFloat)((shapeColorLong & 0x0000FF00) >> 8) / 0xFF
                                               blue:(CGFloat)((shapeColorLong & 0x000000FF)) / 0xFF
                                              alpha:(CGFloat)((shapeColorLong & 0xFF000000) >> 24) / 0xFF];
        if (CGColorGetComponents(shapeColor.CGColor)[3] != 0.0) {
            self.entityStrokeColor = shapeColor;
        }
    }
    
    if (![dict[@"shapeStrokeWidth"] isEqual:[NSNull null]]) {
        self.entityStrokeWidth = [dict[@"shapeStrokeWidth"] doubleValue];
    }
}

- (void)addEntity:(NSString *)entityType textShapeFontType:(NSString *)textShapeFontType textShapeFontSize:(NSNumber *)textShapeFontSize textShapeText:(NSString *)textShapeText imageShapeAsset:(NSString *)imageShapeAsset {
    
    switch ([@[@"Circle", @"Rect", @"Square", @"Triangle", @"Arrow", @"Text", @"Image"] indexOfObject: entityType]) {
        case 1:
            [self addRectEntity:300 andHeight:150];
            break;
        case 2:
            [self addRectEntity:300 andHeight:300];
            break;
        case 3:
            [self addTriangleEntity];
            break;
        case 4:
            [self addArrowEntity];
            break;
        case 5:
            [self addTextEntity:textShapeFontType withFontSize:textShapeFontSize withText:textShapeText];
            break;
        case 6:
            // TODO: ImageEntity Doesn't exist yet
        case 0:
        case NSNotFound:
        default: {
            [self addCircleEntity];
            break;
        }
    }
}

- (void)addCircleEntity {
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);
    
    CircleEntity *entity = [[CircleEntity alloc]
                            initAndSetupWithParent:self.bounds.size.width
                            parentHeight:self.bounds.size.height
                            parentCenterX:centerX
                            parentCenterY:centerY
                            parentScreenScale:self.window.screen.scale
                            width:300
                            height:300
                            bordersPadding:5.0f
                            borderStyle:self.entityBorderStyle
                            borderStrokeWidth:self.entityBorderStrokeWidth
                            borderStrokeColor:self.entityBorderColor
                            entityStrokeWidth:self.entityStrokeWidth
                            entityStrokeColor:self.entityStrokeColor];
    
    [self.motionEntities addObject:entity];
    [self onShapeSelectionChanged:entity];
    [self selectEntity:entity];
}

- (void)addRectEntity:(NSInteger)width andHeight: (NSInteger)height {
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);
    
    RectEntity *entity = [[RectEntity alloc]
                          initAndSetupWithParent:self.bounds.size.width
                          parentHeight:self.bounds.size.height
                          parentCenterX:centerX
                          parentCenterY:centerY
                          parentScreenScale:self.window.screen.scale
                          width:width
                          height:height
                          bordersPadding:5.0f
                          borderStyle:self.entityBorderStyle
                          borderStrokeWidth:self.entityBorderStrokeWidth
                          borderStrokeColor:self.entityBorderColor
                          entityStrokeWidth:self.entityStrokeWidth
                          entityStrokeColor:self.entityStrokeColor];
    
    [self.motionEntities addObject:entity];
    [self onShapeSelectionChanged:entity];
    [self selectEntity:entity];
}

- (void)addTriangleEntity {
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);
    
    TriangleEntity *entity = [[TriangleEntity alloc]
                              initAndSetupWithParent:self.bounds.size.width
                              parentHeight:self.bounds.size.height
                              parentCenterX:centerX
                              parentCenterY:centerY
                              parentScreenScale:self.window.screen.scale
                              width:300
                              height:300
                              bordersPadding:5.0f
                              borderStyle:self.entityBorderStyle
                              borderStrokeWidth:self.entityBorderStrokeWidth
                              borderStrokeColor:self.entityBorderColor
                              entityStrokeWidth:self.entityStrokeWidth
                              entityStrokeColor:self.entityStrokeColor];
    
    [self.motionEntities addObject:entity];
    [self onShapeSelectionChanged:entity];
    [self selectEntity:entity];
}

- (void)addArrowEntity {
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);
    
    ArrowEntity *entity = [[ArrowEntity alloc]
                              initAndSetupWithParent:self.bounds.size.width
                              parentHeight:self.bounds.size.height
                              parentCenterX:centerX
                              parentCenterY:centerY
                              parentScreenScale:self.window.screen.scale
                              width:300
                              height:300
                              bordersPadding:5.0f
                              borderStyle:self.entityBorderStyle
                              borderStrokeWidth:self.entityBorderStrokeWidth
                              borderStrokeColor:self.entityBorderColor
                              entityStrokeWidth:self.entityStrokeWidth
                              entityStrokeColor:self.entityStrokeColor];
    
    [self.motionEntities addObject:entity];
    [self onShapeSelectionChanged:entity];
    [self selectEntity:entity];
}

- (void)addTextEntity:(NSString *)fontType withFontSize: (NSNumber *)fontSize withText: (NSString *)text {
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMidY(self.bounds);
    
    TextEntity *entity = [[TextEntity alloc]
                           initAndSetupWithParent:self.bounds.size.width
                           parentHeight:self.bounds.size.height
                           parentCenterX:centerX
                           parentCenterY:centerY
                           parentScreenScale:self.window.screen.scale
                           text:text
                           fontType:fontType
                           fontSize:[fontSize floatValue]
                           bordersPadding:5.0f
                           borderStyle:self.entityBorderStyle
                           borderStrokeWidth:self.entityBorderStrokeWidth
                           borderStrokeColor:self.entityBorderColor
                           entityStrokeWidth:self.entityStrokeWidth
                           entityStrokeColor:self.entityStrokeColor];
    
    [self.motionEntities addObject:entity];
    [self onShapeSelectionChanged:entity];
    [self selectEntity:entity];
}

- (void)fillShape {
    if (self.selectedEntity) {
        [self.selectedEntity setIsFilled:![self.selectedEntity isEntityFilled]];
        [self.selectedEntity setNeedsDisplay];
    }
}

- (void)selectEntity:(MotionEntity *)entity {
    if (self.selectedEntity) {
        [self.selectedEntity setIsSelected:NO];
        [self.selectedEntity setNeedsDisplay];
    }
    if (entity) {
        [entity setIsSelected:YES];
        [entity setNeedsDisplay];
        [_pathEntity setFrozenImageNeedsUpdate];
        [self setNeedsDisplayInRect:entity.bounds];
    } else {
        [self setNeedsDisplay];
    }
    self.selectedEntity = entity;
}

- (void)updateSelectionOnTapWithLocationPoint:(CGPoint)tapLocation {
    MotionEntity *nextEntity = [self findEntityAtPointX:tapLocation.x andY:tapLocation.y];
    [self onShapeSelectionChanged:nextEntity];
    [self selectEntity:nextEntity];
}

- (MotionEntity *)findEntityAtPointX:(CGFloat)x andY: (CGFloat)y {
    MotionEntity *nextEntity = nil;
    CGPoint point = CGPointMake(x, y);
    for (MotionEntity *entity in self.motionEntities) {
        if ([entity isPointInEntity:point]) {
            nextEntity = entity;
            break;
        }
    }
    return nextEntity;
}

- (void)releaseSelectedEntity {
    MotionEntity *entityToRemove = nil;
    for (MotionEntity *entity in self.motionEntities) {
        if ([entity isSelected]) {
            entityToRemove = entity;
            break;
        }
    }
    if (entityToRemove) {
        [self.motionEntities removeObject:entityToRemove];
        [entityToRemove removeFromSuperview];
        entityToRemove = nil;
        [self selectEntity:entityToRemove];
        [self onShapeSelectionChanged:nil];
    }
}

- (void)unselectShape {
    [self selectEntity:nil];
}

- (void)increaseTextEntityFontSize {
    TextEntity *textEntity = [self getSelectedTextEntity];
    if (textEntity) {
        [textEntity updateFontSize:textEntity.fontSize + 1];
        [textEntity setNeedsDisplay];
    }
}

- (void)decreaseTextEntityFontSize {
    TextEntity *textEntity = [self getSelectedTextEntity];
    if (textEntity) {
        [textEntity updateFontSize:textEntity.fontSize - 1];
        [textEntity setNeedsDisplay];
    }
}

- (void)setTextEntityText:(NSString *)newText {
    TextEntity *textEntity = [self getSelectedTextEntity];
    if (textEntity && newText && [newText length] > 0) {
        [textEntity updateText:newText];
        [textEntity setNeedsDisplay];
    }
}

- (TextEntity *)getSelectedTextEntity {
    if (self.selectedEntity && [self.selectedEntity isKindOfClass:[TextEntity class]]) {
        return (TextEntity *)self.selectedEntity;
    } else {
        return nil;
    }
}

#pragma mark - UIGestureRecognizers
- (void)handleTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint tapLocation = [sender locationInView:sender.view];
        [self updateSelectionOnTapWithLocationPoint:tapLocation];
    }
}

- (void)handleRotate:(UIRotationGestureRecognizer *)sender {
    UIGestureRecognizerState state = [sender state];
    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
        if (self.selectedEntity) {
            [self.selectedEntity rotateEntityBy:sender.rotation];
            [self setNeedsDisplayInRect:self.selectedEntity.bounds];
        }
        [sender setRotation:0.0];
    }
}

- (void)moveSelectedShape: (NSDictionary *)actionObject {
    if(self.selectedEntity) {
        CGFloat newValueX = [[actionObject valueForKeyPath:@"value.x"] floatValue];
        CGFloat newValueY = [[actionObject valueForKeyPath:@"value.y"] floatValue];
        CGPoint newPoint = CGPointMake(newValueX, newValueY);
        [self.selectedEntity moveEntityTo: newPoint];
        [self setNeedsDisplayInRect:self.selectedEntity.bounds];
    }
}

- (void)handleMove:(UIPanGestureRecognizer *)sender {
    UIGestureRecognizerState state = [sender state];
    if (self.selectedEntity) {
        if (state != UIGestureRecognizerStateCancelled) {
            [self.selectedEntity moveEntityTo:[sender translationInView:self.selectedEntity]];
            [sender setTranslation:CGPointZero inView:sender.view];
            [self setNeedsDisplayInRect:self.selectedEntity.bounds];
        }
    }
}

- (void)handleScale:(UIPinchGestureRecognizer *)sender {
    UIGestureRecognizerState state = [sender state];
    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
        if (self.selectedEntity) {
            [self.selectedEntity scaleEntityBy:sender.scale];
            [self setNeedsDisplayInRect:self.selectedEntity.bounds];
        }
        [sender setScale:1.0];
    }
}

#pragma mark - Outgoing events
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo: (void *) contextInfo {
    if (_onChange) {
        _onChange(@{ @"success": error != nil ? @NO : @YES });
    }
}

- (void)notifyPathsUpdate:(int) count{
    if (_onChange) {
        _onChange(@{ @"pathsUpdate": @(count) });
    }
}

- (void)onShapeSelectionChanged:(MotionEntity *)nextEntity {
    BOOL isShapeSelected = NO;
    if (nextEntity) {
        isShapeSelected = YES;
    }
    if (_onChange) {
        if (isShapeSelected) {
            _onChange(@{ @"isShapeSelected": @YES });
        } else {
            // Add delay!
            _onChange(@{ @"isShapeSelected": @NO });
        }
    }
}

@end

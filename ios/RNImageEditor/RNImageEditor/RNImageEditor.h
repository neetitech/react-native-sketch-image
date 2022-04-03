#import <UIKit/UIKit.h>
#import "entities/base/Enumerations.h"
#import "entities/base/MotionEntity.h"

@class RCTEventDispatcher;

@interface RNImageEditor : UIView <UIGestureRecognizerDelegate>

@property (nonatomic, copy) RCTBubblingEventBlock onChange;
@property (nonatomic) NSMutableArray<MotionEntity *> *motionEntities;
@property (nonatomic) MotionEntity *selectedEntity;
@property (nonatomic) UIColor *entityBorderColor;
@property (nonatomic) enum BorderStyle entityBorderStyle;
@property (nonatomic) CGFloat entityBorderStrokeWidth;
@property (nonatomic) CGFloat entityStrokeWidth;
@property (nonatomic) UIColor *entityStrokeColor;
@property (nonatomic) UITapGestureRecognizer *tapGesture;
@property (nonatomic) UIRotationGestureRecognizer *rotateGesture;
@property (nonatomic) UIPanGestureRecognizer *moveGesture;
@property (nonatomic) UIPinchGestureRecognizer *scaleGesture;

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher;

- (BOOL)openSketchFile:(NSString *)filename directory:(NSString*) directory contentMode:(NSString*)mode;
- (void)setCanvasText:(NSArray *)text;
- (void)newPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth;
- (void)addPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth points:(NSArray*) points;
- (void)deletePath:(int) pathId;
- (void)addPointX: (float)x Y: (float)y isMove: (BOOL)isMove;
- (void)endPath;
- (void)clear;
- (void)saveImageOfType:(NSString*) type folder:(NSString*) folder filename:(NSString*) filename withTransparentBackground:(BOOL) transparent includeImage:(BOOL)includeImage includeText:(BOOL)includeText cropToImageSize:(BOOL)cropToImageSize;
- (NSString*) transferToBase64OfType: (NSString*) type withTransparentBackground: (BOOL) transparent includeImage:(BOOL)includeImage includeText:(BOOL)includeText cropToImageSize:(BOOL)cropToImageSize;
- (void)setShapeConfiguration:(NSDictionary *)dict;
- (void)addEntity:(NSString *)entityType textShapeFontType: (NSString *)textShapeFontType textShapeFontSize: (NSNumber *)textShapeFontSize textShapeText: (NSString *)textShapeText imageShapeAsset: (NSString *)imageShapeAsset;
- (void)releaseSelectedEntity;
- (void)unselectShape;
- (void)increaseTextEntityFontSize;
- (void)decreaseTextEntityFontSize;
- (void)setTextEntityText:(NSString *)newText;
- (void)moveSelectedShape: (NSDictionary *)actionObject;
@end

//
//  PathEntity.h
//  RNImageEditor
//

#import "base/MotionEntity.h"
#import "RNImageEditorData.h"

@protocol PathUpdateDelegate
- (void)notifyPathsUpdate:(NSUInteger)count;
@end

@interface PathEntity: UIView

@property (nonatomic) RNImageEditorData* activePath;
@property (nonatomic) NSMutableArray* pathList;
@property BOOL _needsFullRedraw;
@property (nonatomic) CGFloat entityStrokeWidth;
@property (nonatomic) UIColor *entityStrokeColor;
@property (nonatomic, weak) id <PathUpdateDelegate> delegate;
@property CGImageRef translucentFrozenImage;
@property CGImageRef frozenImage;

- (instancetype)initAndSetupWithParent: (NSInteger)parentWidth
                          parentHeight: (NSInteger)parentHeight
                                 width: (NSInteger)width
                                height: (NSInteger)height
                     entityStrokeWidth: (CGFloat)entityStrokeWidth
                     entityStrokeColor: (UIColor *)entityStrokeColor;

- (void)addPointX:(float)x Y: (float)y;
- (void)endPath;
- (void) clear;
- (void)setFrozenImageNeedsUpdate;
- (void)deletePath:(int) pathId;
- (void)newPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth;
- (void) addPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth points:(NSArray*) points;
@end


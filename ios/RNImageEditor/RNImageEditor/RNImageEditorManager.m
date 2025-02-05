#import "RNImageEditorManager.h"
#import "RNImageEditor.h"
#import <React/RCTEventDispatcher.h>
#import <React/RCTView.h>
#import <React/UIView+React.h>
#import <React/RCTUIManager.h>
#import "entities/base/Enumerations.h"

@implementation RNImageEditorManager

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

-(NSDictionary *)constantsToExport {
    return @{
             @"MainBundlePath": [[NSBundle mainBundle] bundlePath],
             @"NSDocumentDirectory": [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject],
             @"NSLibraryDirectory": [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject],
             @"NSCachesDirectory": [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject],
             };
}

#pragma mark - Events

RCT_EXPORT_VIEW_PROPERTY(onChange, RCTBubblingEventBlock);

#pragma mark - Props
RCT_CUSTOM_VIEW_PROPERTY(shapeConfiguration, NSDictionary, RNImageEditor)
{
    RNImageEditor *currentView = !view ? defaultView : view;
    NSDictionary *dict = [RCTConvert NSDictionary:json];
    dispatch_async(dispatch_get_main_queue(), ^{
        [currentView setShapeConfiguration:dict];
    });
}

RCT_CUSTOM_VIEW_PROPERTY(localSourceImage, NSDictionary, RNImageEditor)
{
    RNImageEditor *currentView = !view ? defaultView : view;
    NSDictionary *dict = [RCTConvert NSDictionary:json];
    dispatch_async(dispatch_get_main_queue(), ^{
        [currentView openSketchFile:dict[@"filename"]
                          directory:[dict[@"directory"] isEqual: [NSNull null]] ? @"" : dict[@"directory"]
                        contentMode:[dict[@"mode"] isEqual: [NSNull null]] ? @"" : dict[@"mode"]];
    });
}

RCT_CUSTOM_VIEW_PROPERTY(text, NSArray, RNImageEditor)
{
    RNImageEditor *currentView = !view ? defaultView : view;
    NSArray *arr = [RCTConvert NSArray:json];
    dispatch_async(dispatch_get_main_queue(), ^{
        [currentView setCanvasText:arr];
    });
}

#pragma mark - Lifecycle

- (UIView *)view
{
    return [[RNImageEditor alloc] initWithEventDispatcher: self.bridge.eventDispatcher];
}

#pragma mark - Exported methods


RCT_EXPORT_METHOD(save:(nonnull NSNumber *)reactTag type:(NSString*) type folder:(NSString*) folder filename:(NSString*) filename withTransparentBackground:(BOOL) transparent includeImage:(BOOL)includeImage includeText:(BOOL)includeText cropToImageSize:(BOOL)cropToImageSize)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas saveImageOfType:type folder:folder filename:filename withTransparentBackground:transparent includeImage:includeImage includeText:includeText cropToImageSize:cropToImageSize];
    }];
}

RCT_EXPORT_METHOD(addPoint:(nonnull NSNumber *)reactTag x: (float)x y: (float)y isMove: (BOOL)isMove)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas addPointX:x Y:y isMove:isMove];
    }];
}

RCT_EXPORT_METHOD(addPath:(nonnull NSNumber *)reactTag pathId: (int) pathId strokeColor: (UIColor*) strokeColor strokeWidth: (int) strokeWidth points: (NSArray*) points)
{
    NSMutableArray *cgPoints = [[NSMutableArray alloc] initWithCapacity: points.count];
    for (NSString *coor in points) {
        NSArray *coorInNumber = [coor componentsSeparatedByString: @","];
        [cgPoints addObject: [NSValue valueWithCGPoint: CGPointMake([coorInNumber[0] floatValue], [coorInNumber[1] floatValue])]];
    }

    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas addPath: pathId strokeColor: strokeColor strokeWidth: strokeWidth points: cgPoints];
    }];
}

RCT_EXPORT_METHOD(newPath:(nonnull NSNumber *)reactTag pathId: (int) pathId strokeColor: (UIColor*) strokeColor strokeWidth: (int) strokeWidth)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas newPath: pathId strokeColor: strokeColor strokeWidth: strokeWidth];
    }];
}

RCT_EXPORT_METHOD(deletePath:(nonnull NSNumber *)reactTag pathId: (int) pathId)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas deletePath: pathId];
    }];
}

RCT_EXPORT_METHOD(endPath:(nonnull NSNumber *)reactTag)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas endPath];
    }];
}

RCT_EXPORT_METHOD(clear:(nonnull NSNumber *)reactTag)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas clear];
    }];
}

RCT_EXPORT_METHOD(layerUpdate:(nonnull NSNumber *)reactTag type:(BOOL) type)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas layerUpdate:type];
    }];
}

RCT_EXPORT_METHOD(transferToBase64:(nonnull NSNumber *)reactTag type: (NSString*) type withTransparentBackground:(BOOL) transparent includeImage:(BOOL)includeImage includeText:(BOOL)includeText cropToImageSize:(BOOL)cropToImageSize :(RCTResponseSenderBlock)callback)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        callback(@[[NSNull null], [canvas transferToBase64OfType: type withTransparentBackground: transparent includeImage:includeImage includeText:includeText cropToImageSize:cropToImageSize]]);
    }];
}

RCT_EXPORT_METHOD(deleteSelectedShape:(nonnull NSNumber *)reactTag)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas releaseSelectedEntity];
    }];
}

RCT_EXPORT_METHOD(unselectShape:(nonnull NSNumber *)reactTag)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas unselectShape];
    }];
}

RCT_EXPORT_METHOD(addShape:(nonnull NSNumber *)reactTag shapeType:(NSString *) shapeType textShapeFontType:(NSString *) textShapeFontType textShapeFontSize:(nonnull NSNumber *) textShapeFontSize textShapeText:(NSString *) textShapeText imageShapeAsset:(NSString *)imageShapeAsset)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas addEntity:shapeType textShapeFontType:textShapeFontType textShapeFontSize:textShapeFontSize textShapeText:textShapeText imageShapeAsset:imageShapeAsset];
    }];
}

RCT_EXPORT_METHOD(fillShape:(nonnull NSNumber *)reactTag)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas fillShape];
    }];
}

RCT_EXPORT_METHOD(increaseShapeFontsize:(nonnull NSNumber *)reactTag)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas increaseTextEntityFontSize];
    }];
}

RCT_EXPORT_METHOD(decreaseShapeFontsize:(nonnull NSNumber *)reactTag)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas decreaseTextEntityFontSize];
    }];
}

RCT_EXPORT_METHOD(changeShapeText:(nonnull NSNumber *)reactTag newText:(NSString *) newText)
{
    [self runCanvas:reactTag block:^(RNImageEditor *canvas) {
        [canvas setTextEntityText:newText];
    }];
}

#pragma mark - Utils

- (void)runCanvas:(nonnull NSNumber *)reactTag block:(void (^)(RNImageEditor *canvas))block {
    [self.bridge.uiManager addUIBlock:
     ^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNImageEditor *> *viewRegistry){

         RNImageEditor *view = viewRegistry[reactTag];
         if (!view || ![view isKindOfClass:[RNImageEditor class]]) {
             RCTLogError(@"Cannot find RNImageEditor with tag #%@", reactTag);
             return;
         }

         block(view);
     }];
}

@end

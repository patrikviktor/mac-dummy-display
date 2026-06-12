#ifndef DummyDisplay_Bridging_Header_h
#define DummyDisplay_Bridging_Header_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// CGVirtualDisplayMode representing a single display resolution and refresh rate
@interface CGVirtualDisplayMode : NSObject

@property (readonly, nonatomic) unsigned int width;
@property (readonly, nonatomic) unsigned int height;
@property (readonly, nonatomic) double refreshRate;

- (instancetype)initWithWidth:(unsigned int)width height:(unsigned int)height refreshRate:(double)refreshRate;

@end

// CGVirtualDisplaySettings containing an array of modes and HiDPI setting
@interface CGVirtualDisplaySettings : NSObject

@property (retain, nonatomic) NSArray<CGVirtualDisplayMode *> *modes;
@property (nonatomic) unsigned int hiDPI;

- (instancetype)init;

@end

// CGVirtualDisplayDescriptor containing vendor/product IDs, display name, and dispatch queue
@interface CGVirtualDisplayDescriptor : NSObject

@property (retain, nonatomic) dispatch_queue_t queue;
@property (retain, nonatomic) NSString *name;
@property (nonatomic) unsigned int vendorID;
@property (nonatomic) unsigned int productID;
@property (nonatomic) unsigned int serialNum;
@property (nonatomic) struct CGSize sizeInMillimeters;
@property (nonatomic) unsigned int maxPixelsWide;
@property (nonatomic) unsigned int maxPixelsHigh;
@property (copy, nonatomic) void (^terminationHandler)(id display);

- (instancetype)init;

@end

// CGVirtualDisplay itself, which manages the virtual display lifecycle
@interface CGVirtualDisplay : NSObject

@property (readonly, nonatomic) NSArray<CGVirtualDisplayMode *> *modes;
@property (readonly, nonatomic) unsigned int hiDPI;
@property (readonly, nonatomic) unsigned int displayID;
@property (readonly, nonatomic) void (^terminationHandler)(id display);
@property (readonly, nonatomic) dispatch_queue_t queue;

- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;

@end

NS_ASSUME_NONNULL_END

#endif /* DummyDisplay_Bridging_Header_h */

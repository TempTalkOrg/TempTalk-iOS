//
//  DTGIFSearchResult.h
//  TempTalk
//
//  GIF search/trending response model (proxy over GIPHY).
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTGIFSearchAsset: MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *gif;
@property (nonatomic, copy) NSString *webp;
@property (nonatomic, copy) NSString *width;
@property (nonatomic, copy) NSString *height;

@end

@interface DTGIFSearchAssetInfo: MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) DTGIFSearchAsset *previewAsset;
@property (nonatomic, strong) DTGIFSearchAsset *originalAsset;

@end

@interface DTGIFSearchPagination: MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) NSInteger count;
@property (nonatomic, assign) NSInteger offset;
@property (nonatomic, assign) NSInteger totalCount;

@end

@interface DTGIFSearchResult: MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSArray<DTGIFSearchAssetInfo *> *data;
@property (nonatomic, strong, nullable) DTGIFSearchPagination *pagination;
@property (nonatomic, copy, nullable) NSString *next;

@end

NS_ASSUME_NONNULL_END

//
//  SignalYYClassInfo.h
//  TTServiceKit
//
//  Created by hornet on 2021/9/26.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
NS_ASSUME_NONNULL_BEGIN
/**
 Type encoding's type.
 */
typedef NS_OPTIONS(NSUInteger, SignalYYEncodingType) {
    SignalYYEncodingTypeMask       = 0xFF, ///< mask of type value
    SignalYYEncodingTypeUnknown    = 0, ///< unknown
    SignalYYEncodingTypeVoid       = 1, ///< void
    SignalYYEncodingTypeBool       = 2, ///< bool
    SignalYYEncodingTypeInt8       = 3, ///< char / BOOL
    SignalYYEncodingTypeUInt8      = 4, ///< unsigned char
    SignalYYEncodingTypeInt16      = 5, ///< short
    SignalYYEncodingTypeUInt16     = 6, ///< unsigned short
    SignalYYEncodingTypeInt32      = 7, ///< int
    SignalYYEncodingTypeUInt32     = 8, ///< unsigned int
    SignalYYEncodingTypeInt64      = 9, ///< long long
    SignalYYEncodingTypeUInt64     = 10, ///< unsigned long long
    SignalYYEncodingTypeFloat      = 11, ///< float
    SignalYYEncodingTypeDouble     = 12, ///< double
    SignalYYEncodingTypeLongDouble = 13, ///< long double
    SignalYYEncodingTypeObject     = 14, ///< id
    SignalYYEncodingTypeClass      = 15, ///< Class
    SignalYYEncodingTypeSEL        = 16, ///< SEL
    SignalYYEncodingTypeBlock      = 17, ///< block
    SignalYYEncodingTypePointer    = 18, ///< void*
    SignalYYEncodingTypeStruct     = 19, ///< struct
    SignalYYEncodingTypeUnion      = 20, ///< union
    SignalYYEncodingTypeCString    = 21, ///< char*
    SignalYYEncodingTypeCArray     = 22, ///< char[10] (for example)
    
    SignalYYEncodingTypeQualifierMask   = 0xFF00,   ///< mask of qualifier
    SignalYYEncodingTypeQualifierConst  = 1 << 8,  ///< const
    SignalYYEncodingTypeQualifierIn     = 1 << 9,  ///< in
    SignalYYEncodingTypeQualifierInout  = 1 << 10, ///< inout
    SignalYYEncodingTypeQualifierOut    = 1 << 11, ///< out
    SignalYYEncodingTypeQualifierBycopy = 1 << 12, ///< bycopy
    SignalYYEncodingTypeQualifierByref  = 1 << 13, ///< byref
    SignalYYEncodingTypeQualifierOneway = 1 << 14, ///< oneway
    
    SignalYYEncodingTypePropertyMask         = 0xFF0000, ///< mask of property
    SignalYYEncodingTypePropertyReadonly     = 1 << 16, ///< readonly
    SignalYYEncodingTypePropertyCopy         = 1 << 17, ///< copy
    SignalYYEncodingTypePropertyRetain       = 1 << 18, ///< retain
    SignalYYEncodingTypePropertyNonatomic    = 1 << 19, ///< nonatomic
    SignalYYEncodingTypePropertyWeak         = 1 << 20, ///< weak
    SignalYYEncodingTypePropertyCustomGetter = 1 << 21, ///< getter=
    SignalYYEncodingTypePropertyCustomSetter = 1 << 22, ///< setter=
    SignalYYEncodingTypePropertyDynamic      = 1 << 23, ///< @dynamic
};

/**
 Get the type from a Type-Encoding string.
 
 @discussion See also:
 https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
 https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
 
 @param typeEncoding  A Type-Encoding string.
 @return The encoding type.
 */
SignalYYEncodingType SignalYYEncodingGetType(const char *typeEncoding);



/**
 Instance variable information.
 */
@interface SignalYYClassIvarInfo : NSObject
@property (nonatomic, assign, readonly) Ivar ivar;              ///< ivar opaque struct
@property (nonatomic, strong, readonly) NSString *name;         ///< Ivar's name
@property (nonatomic, assign, readonly) ptrdiff_t offset;       ///< Ivar's offset
@property (nonatomic, strong, readonly) NSString *typeEncoding; ///< Ivar's type encoding
@property (nonatomic, assign, readonly) SignalYYEncodingType type;    ///< Ivar's type

/**
 Creates and returns an ivar info object.
 
 @param ivar ivar opaque struct
 @return A new object, or nil if an error occurs.
 */
- (instancetype)initWithIvar:(Ivar)ivar;
@end


/**
 Method information.
 */
@interface SignalYYClassMethodInfo : NSObject
@property (nonatomic, assign, readonly) Method method;                  ///< method opaque struct
@property (nonatomic, strong, readonly) NSString *name;                 ///< method name
@property (nonatomic, assign, readonly) SEL sel;                        ///< method's selector
@property (nonatomic, assign, readonly) IMP imp;                        ///< method's implementation
@property (nonatomic, strong, readonly) NSString *typeEncoding;         ///< method's parameter and return types
@property (nonatomic, strong, readonly) NSString *returnTypeEncoding;   ///< return value's type
@property (nullable, nonatomic, strong, readonly) NSArray<NSString *> *argumentTypeEncodings; ///< array of arguments' type

/**
 Creates and returns a method info object.
 
 @param method method opaque struct
 @return A new object, or nil if an error occurs.
 */
- (instancetype)initWithMethod:(Method)method;
@end


/**
 Property information.
 */
@interface SignalYYClassPropertyInfo : NSObject
@property (nonatomic, assign, readonly) objc_property_t property; ///< property's opaque struct
@property (nonatomic, strong, readonly) NSString *name;           ///< property's name
@property (nonatomic, assign, readonly) SignalYYEncodingType type;      ///< property's type
@property (nonatomic, strong, readonly) NSString *typeEncoding;   ///< property's encoding value
@property (nonatomic, strong, readonly) NSString *ivarName;       ///< property's ivar name
@property (nullable, nonatomic, assign, readonly) Class cls;      ///< may be nil
@property (nullable, nonatomic, strong, readonly) NSArray<NSString *> *protocols; ///< may nil
@property (nonatomic, assign, readonly) SEL getter;               ///< getter (nonnull)
@property (nonatomic, assign, readonly) SEL setter;               ///< setter (nonnull)

/**
 Creates and returns a property info object.
 
 @param property property opaque struct
 @return A new object, or nil if an error occurs.
 */
- (instancetype)initWithProperty:(objc_property_t)property;
@end

@interface SignalYYClassInfo : NSObject
@property (nonatomic, assign, readonly) Class cls; ///< class object
@property (nullable, nonatomic, assign, readonly) Class superCls; ///< super class object
@property (nullable, nonatomic, assign, readonly) Class metaCls;  ///< class's meta class object
@property (nonatomic, readonly) BOOL isMeta; ///< whether this class is meta class
@property (nonatomic, strong, readonly) NSString *name; ///< class name
@property (nullable, nonatomic, strong, readonly) SignalYYClassInfo *superClassInfo; ///< super class's class info
@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, SignalYYClassIvarInfo *> *ivarInfos; ///< ivars
@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, SignalYYClassMethodInfo *> *methodInfos; ///< methods
@property (nullable, nonatomic, strong, readonly) NSDictionary<NSString *, SignalYYClassPropertyInfo *> *propertyInfos; ///< properties

/**
 If the class is changed (for example: you add a method to this class with
 'class_addMethod()'), you should call this method to refresh the class info cache.
 
 After called this method, `needUpdate` will returns `YES`, and you should call
 'classInfoWithClass' or 'classInfoWithClassName' to get the updated class info.
 */
- (void)setNeedUpdate;

/**
 If this method returns `YES`, you should stop using this instance and call
 `classInfoWithClass` or `classInfoWithClassName` to get the updated class info.
 
 @return Whether this class info need update.
 */
- (BOOL)needUpdate;

/**
 Get the class info of a specified Class.
 
 @discussion This method will cache the class info and super-class info
 at the first access to the Class. This method is thread-safe.
 
 @param cls A class.
 @return A class info, or nil if an error occurs.
 */
+ (nullable instancetype)classInfoWithClass:(Class)cls;

/**
 Get the class info of a specified Class.
 
 @discussion This method will cache the class info and super-class info
 at the first access to the Class. This method is thread-safe.
 
 @param className A class name.
 @return A class info, or nil if an error occurs.
 */
+ (nullable instancetype)classInfoWithClassName:(NSString *)className;
@end

NS_ASSUME_NONNULL_END

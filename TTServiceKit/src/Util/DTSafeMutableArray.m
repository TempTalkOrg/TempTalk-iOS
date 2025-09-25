//
//  DTSafeMutableArray.m
//  TTServiceKit
//
//  Created by Felix on 2022/10/20.
//

#import "DTSafeMutableArray.h"

@interface DTSafeMutableArray()

@property (nonatomic, strong) NSMutableArray * mArray;
@property (nonatomic, strong) dispatch_queue_t syncQueue;

@end

@implementation DTSafeMutableArray

- (instancetype)initCommon {
    if (self = [super init]) {
        
        // %p 以 16 进制的形式输出内存地址，附加前缀 0x
        NSString * uuid = [NSString stringWithFormat:@"org.difft.array_%p", self];
        
        // 注意：_syncQueue 是并行队列
        _syncQueue = dispatch_queue_create([uuid UTF8String], DISPATCH_QUEUE_CONCURRENT);
    }
    
    return self;
}

- (instancetype)init
{
    if (self = [self initCommon]) {
        
        _mArray = [NSMutableArray array];
    }
    
    return self;
}


- (id)objectAtIndex:(NSUInteger)index {
    __block id obj;
    
    dispatch_sync(_syncQueue, ^{
        
        if (index < [self.mArray count]) {
            
            obj = self.mArray[index];
        }
    });
    
    return obj;
}


- (NSEnumerator *)objectEnumerator {
    __block NSEnumerator * enu;
    
    dispatch_sync( _syncQueue, ^{
        
        enu = [self.mArray objectEnumerator];
    });
    
    return enu;
}

- (NSUInteger)containsObject:(id)anObject {
    
    __block BOOL result = NO;
    
    dispatch_sync( _syncQueue, ^{
        
        result = [self.mArray containsObject:anObject];
    });
    
    return result;
}


- (void)insertObject:(id)anObject atIndex:(NSUInteger)index {
    
    dispatch_barrier_async( _syncQueue, ^{
        
        if (anObject) {
            
            if (index < [self.mArray count]) {
                
                [self.mArray insertObject:anObject atIndex:index];
            } else { // index > array.count
                
                [self.mArray addObject:anObject];
            }
        }
    });
}


- (void)removeObject:(id)anObject {
    
    dispatch_barrier_async( _syncQueue, ^{
        
        if(anObject){
            
            [self.mArray removeObject:anObject];
        }
    });
}

- (void)addObject:(id)anObject {
    
    dispatch_barrier_async( _syncQueue, ^{
        
        if(anObject){
            
            [self.mArray addObject:anObject];
        }
    });
}


- (void)removeObjectAtIndex:(NSUInteger)index {
    
    dispatch_barrier_async( _syncQueue, ^{
        
        if (index < [self.mArray count]) {
            
            [self.mArray removeObjectAtIndex:index];
        }
    });
}

- (void)removeAllObjects {
    
    dispatch_barrier_async( _syncQueue, ^{
        
        [self.mArray removeAllObjects];
    });
}


- (void)removeLastObject {
    
    dispatch_barrier_async( _syncQueue, ^{
        
        [self.mArray removeLastObject];
    });
}


- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject {
    
    dispatch_barrier_async( _syncQueue, ^{
        
        if (anObject && index < [self.mArray count]) {
            
            [self.mArray replaceObjectAtIndex:index withObject:anObject];
        }
    });
}

- (NSUInteger)indexOfObject:(id)anObject {
    
    __block NSUInteger index = NSNotFound;
    
    dispatch_sync( _syncQueue, ^{
        
        for (int i = 0; i < [_mArray count]; i ++) {
            
            if ([_mArray objectAtIndex:i] == anObject) {
                
                index = i;
                
                break;
            }
        }
    });
    
    return index;
}


- (NSUInteger)count {
    __block NSUInteger count = 0;
    
    dispatch_sync( _syncQueue, ^{
        
        count = [_mArray objectEnumerator].allObjects.count;
    });
    
    return count;
}


- (void)sortedArrayUsingComparator:(NSComparator NS_NOESCAPE)cmptr {
    dispatch_barrier_async( _syncQueue, ^{
        self.mArray = [[self.mArray sortedArrayUsingComparator:cmptr] mutableCopy];
    });
}

- (void)dealloc {
    
    if (_syncQueue) {
        _syncQueue = NULL;
    }
}

@end

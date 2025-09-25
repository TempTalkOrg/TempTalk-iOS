//
//  DTSafeMutableArray.h
//  TTServiceKit
//
//  Created by Felix on 2022/10/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTSafeMutableArray : NSObject

- (id)objectAtIndex:(NSUInteger)index;

- (NSEnumerator *)objectEnumerator;

- (NSUInteger)containsObject:(id)anObject;

- (void)insertObject:(id)anObject atIndex:(NSUInteger)index;

- (void)addObject:(id)anObject;

- (void)removeObject:(id)anObject;

- (void)removeObjectAtIndex:(NSUInteger)index;

- (void)removeLastObject;

- (void)removeAllObjects;

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject;

- (NSUInteger)indexOfObject:(id)anObject;

- (NSUInteger)count;

- (void)sortedArrayUsingComparator:(NSComparator NS_NOESCAPE)cmptr;

@end

NS_ASSUME_NONNULL_END

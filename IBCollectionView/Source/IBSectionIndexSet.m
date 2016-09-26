//
//  IBSectionIndexSet.m
//  iDocument 2.0
//
//  Created by Kevin Lu on 7/2/13.
//  Copyright (c) 2013 Icyblaze. All rights reserved.
//

#import "IBSectionIndexSet.h"

@implementation IBSectionIndexSet

@synthesize itemIndex = _itemIndex, sectionIndex = _sectionIndex;

- (id)copyWithZone:(NSZone*)zone
{
    IBSectionIndexSet *indexSet = (IBSectionIndexSet*)[[self class] allocWithZone: zone];
    indexSet.itemIndex = _itemIndex;
    indexSet.sectionIndex = _sectionIndex;
    return indexSet;
}

-(id)initWithSection:(NSInteger)sectionIndex ItemIndex:(NSInteger)itemIndex
{
    if (self = [super init]){
        _itemIndex = itemIndex;
        _sectionIndex = sectionIndex;
        if (_itemIndex == NSNotFound)
            _itemIndex = 0;
        if (_sectionIndex == NSNotFound)
            _sectionIndex = 0;
    }
    return self;
}

+(id)sectionIndexSetWithSectionIndex:(NSInteger)sectionIndex ItemIndex:(NSInteger)itemIndex
{
    IBSectionIndexSet *result = [[IBSectionIndexSet alloc] initWithSection: sectionIndex ItemIndex: itemIndex];
    return result;
}

-(BOOL)isEqual:(id)object
{
    if (self == object)
        return YES;
    IBSectionIndexSet *tmpSet = object;
    if (tmpSet.itemIndex == _itemIndex && tmpSet.sectionIndex == _sectionIndex)
        return YES;
    return NO;
}

-(NSUInteger)hash
{
    NSUInteger result = (_sectionIndex << 6) | (_itemIndex << 4);
    return result;
}

-(NSString*)description
{
    return [NSString stringWithFormat: @"SectionIndexSet: %ld, %ld", _sectionIndex, _itemIndex];
}

@end

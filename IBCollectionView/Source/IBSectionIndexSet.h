//
//  IBSectionIndexSet.h
//  iDocument 2.0
//
//  Created by Kevin Lu on 7/2/13.
//  Copyright (c) 2013 Icyblaze. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IBSectionIndexSet : NSObject <NSCopying>{
    NSInteger _sectionIndex;    
    NSInteger _itemIndex;
}

-(id)initWithSection:(NSInteger)sectionIndex ItemIndex:(NSInteger)itemIndex;
+(id)sectionIndexSetWithSectionIndex:(NSInteger)sectionIndex ItemIndex:(NSInteger)itemIndex;

@property (assign) NSInteger sectionIndex;
@property (assign) NSInteger itemIndex;

@end
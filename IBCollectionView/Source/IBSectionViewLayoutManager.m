//
//  IBSectionViewLayoutManager.m
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//  https://github.com/icyblazek/IBCollectionView

#import "IBSectionViewLayoutManager.h"

@interface IBSectionViewLayoutManager (){
}

@end

@implementation IBSectionViewLayoutManager

- (id)init
{
    if (self=[super init]) {
        _itemViewHSpacing = 10;
        _itemViewWSpacing = 10;
        _itemViewMarginMinX = 10;
        _itemViewMarginMinY = 10;
        _itemViewMarginMaxX = 10;
        _itemViewMarginMaxY = 10;
        _sectionHeaderViewHeight = 20;
        _sectionBottomViewHeight = 20;
        _itemSize = NSMakeSize(100, 100);
    }
    return self;
}


-(NSUInteger)countOfColumn
{
    NSSize itemSize = [self itemSize];
    CGFloat itemWSpacing = [self itemViewWSpacing];
    
    CGFloat itemMarginMinX = [self itemViewMarginMinX];
    CGFloat itemMarginMaxX = [self itemViewMarginMaxX];
    
    CGFloat usedWidth = _layoutWidth - (itemMarginMinX + itemMarginMaxX);
    NSInteger itemCol = usedWidth / (itemSize.width + itemWSpacing);
    
    if (itemCol == 0)
        itemCol = 1;
    
    return itemCol;
}

-(NSUInteger)columnOfIndex:(NSInteger)index
{
    NSInteger itemCol = [self countOfColumn];
    return index % itemCol;
}

-(NSRect)itemRectOfIndex:(NSInteger)index
{
    NSSize itemSize = [self itemSize];
    CGFloat itemWSpacing = [self itemViewWSpacing];
    CGFloat itemHSpacing = [self itemViewHSpacing];
    
    CGFloat itemMarginMinX = [self itemViewMarginMinX];
    CGFloat itemMarginMaxX = [self itemViewMarginMaxX];
    
    CGFloat headerHeight = [self sectionHeaderViewHeight];
    CGFloat itemMarginMaxY = [self itemViewMarginMaxY];
    
    CGFloat usedWidth = _layoutWidth - (itemMarginMinX + itemMarginMaxX);
    NSInteger maxNumberOfCol = usedWidth / (itemSize.width + itemWSpacing);
    
    if (maxNumberOfCol <= 0)
        maxNumberOfCol = 1;
    
    CGFloat actualWSpace = itemWSpacing;
    BOOL autoWSpacing = NO;
    if (autoWSpacing){
        if (self.itemCount > maxNumberOfCol) {
            CGFloat tmp = usedWidth - maxNumberOfCol * itemSize.width;
            actualWSpace = tmp / (maxNumberOfCol + 1);
        }
        else{
            CGFloat tmp = usedWidth - maxNumberOfCol * itemSize.width;
            actualWSpace = tmp / (maxNumberOfCol + 1);
        }
    }
    
    NSInteger drawIndexX = index % maxNumberOfCol;
    NSInteger drawIndexY = index / maxNumberOfCol;
    CGFloat x = floor(drawIndexX * itemSize.width + (drawIndexX + 1) * actualWSpace + itemMarginMinX);
    CGFloat y = floor(drawIndexY * itemSize.height + drawIndexY * itemHSpacing + itemMarginMaxY + headerHeight);
    NSRect result = NSMakeRect(x, y, itemSize.width, itemSize.height);
    return result;
}

-(NSInteger)itemIndexWithPoint:(NSPoint)point
{
    return 0;
}

-(CGFloat)contentHeightWithLayoutWidht:(CGFloat)layoutWidth
{
    _layoutWidth = layoutWidth;
    NSSize itemSize = [self itemSize];
    CGFloat itemWSpacing = [self itemViewWSpacing];
    CGFloat itemHSpacing = [self itemViewHSpacing];
    
    CGFloat itemMarginMinX = [self itemViewMarginMinX];
    CGFloat itemMarginMaxX = [self itemViewMarginMaxX];
    
    CGFloat itemMarginMinY = [self itemViewMarginMinY];
    CGFloat itemMarginMaxY = [self itemViewMarginMaxY];
    
    CGFloat usedWidth = layoutWidth - (itemMarginMinX + itemMarginMaxX);
    NSInteger itemCol = usedWidth / (itemSize.width + itemWSpacing);
    
    if (itemCol == 0)
        itemCol = 1;
    
    NSInteger itemRow = floor(self.itemCount / itemCol);
    if (self.itemCount > itemCol && self.itemCount % itemCol > 0)
        itemRow++;
    if (self.itemCount < itemCol)
        itemRow = 1;
    if (itemRow == 0)
        itemRow = 1;
    
    CGFloat tmpMaxHeight = itemRow * itemSize.height + (itemRow - 1) * itemHSpacing;
    tmpMaxHeight += itemMarginMinY + itemMarginMaxY;
    tmpMaxHeight += [self sectionHeaderViewHeight] + [self sectionBottomViewHeight];
    return tmpMaxHeight;
}

@end

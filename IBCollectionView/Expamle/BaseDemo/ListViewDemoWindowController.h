//
//  ListViewDemoWindowController.h
//  IBCollectionView
//
//  Created by Kevin on 8/2/15.
//  Copyright (c) 2015 Icyblaze. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IBCollectionView.h"


@interface ListItemView : IBCollectionItemView{
    
}

@end

@interface ListLayoutManager : IBSectionViewLayoutManager{
    
}

@end



@interface ListViewDemoWindowController : NSWindowController{
    IBCollectionView *_collectionView;
}

@end

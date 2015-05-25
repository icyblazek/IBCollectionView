//
//  AppDelegate.m
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//

#import "AppDelegate.h"
#import <objc/message.h>

#import "BaseDemoWindowController.h"
#import "SectionViewDemoWindowController.h"
#import "ListViewDemoWindowController.h"
#import "ViewSwitchDemoWindowController.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

-(IBAction)btnBaseDemoClick:(id)sender
{
    BaseDemoWindowController *wc = [[BaseDemoWindowController alloc] initWithWindowNibName: @"BaseDemoWindowController"];
    [NSApp runModalForWindow: wc.window];
}

-(IBAction)btnSectionViewDemoClick:(id)sender
{
    SectionViewDemoWindowController *wc = [[SectionViewDemoWindowController alloc] initWithWindowNibName: @"SectionViewDemoWindowController"];
    [NSApp runModalForWindow: wc.window];
}

-(IBAction)btnListViewDemoClick:(id)sender
{
    ListViewDemoWindowController *wc = [[ListViewDemoWindowController alloc] initWithWindowNibName: @"ListViewDemoWindowController"];
    [NSApp runModalForWindow: wc.window];
}

-(IBAction)btnViewSwitchDemoClick:(id)sender
{
    ViewSwitchDemoWindowController *wc = [[ViewSwitchDemoWindowController alloc] initWithWindowNibName: @"ViewSwitchDemoWindowController"];
    [NSApp runModalForWindow: wc.window];
}

@end

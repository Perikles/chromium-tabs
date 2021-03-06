// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "CTTabWindowController.h"
#import "CTTabStripView.h"

@interface CTTabWindowController(PRIVATE)
- (void)setUseOverlay:(BOOL)useOverlay;
@end

@interface TabWindowOverlayWindow : NSWindow
@end

@implementation TabWindowOverlayWindow

- (NSPoint)themePatternPhase {
  return NSZeroPoint;
}

@end

@implementation CTTabWindowController
@synthesize tabContentArea = tabContentArea_,
            didShowNewTabButtonBeforeTemporalAction = 
                didShowNewTabButtonBeforeTemporalAction_;

- (id)initWithWindow:(NSWindow*)window {
  if ((self = [super initWithWindow:window]) != nil) {
    lockedTabs_.reset([[NSMutableSet alloc] initWithCapacity:10]);
  }
  return self;
}

- (void)dealloc {
  if (overlayWindow_) {
    [self setUseOverlay:NO];
  }
  [super dealloc];
}


// Add the side tab strip to the left side of the window's content area,
// making it fill the full height of the content area.
- (void)addSideTabStripToWindow {
  NSView* contentView = [[self window] contentView];
  NSRect contentFrame = [contentView frame];
  NSRect sideStripFrame =
      NSMakeRect(0, 0,
                 NSWidth([sideTabStripView_ frame]),
                 NSHeight(contentFrame));
  [sideTabStripView_ setFrame:sideStripFrame];
  [contentView addSubview:sideTabStripView_];
}

// Add the top tab strop to the window, above the content box and add it to the
// view hierarchy as a sibling of the content view so it can overlap with the
// window frame.
- (void)addTopTabStripToWindow {
  NSRect contentFrame = [tabContentArea_ frame];
  NSRect tabFrame =
      NSMakeRect(0, NSMaxY(contentFrame),
                 NSWidth(contentFrame),
                 NSHeight([topTabStripView_ frame]));
  [topTabStripView_ setFrame:tabFrame];
  NSView* contentParent = [[[self window] contentView] superview];
  [contentParent addSubview:topTabStripView_];
}

- (void)windowDidLoad {
  // Cache the difference in height between the window content area and the
  // tab content area.
  NSRect tabFrame = [tabContentArea_ frame];
  NSRect contentFrame = [[[self window] contentView] frame];
  contentAreaHeightDelta_ = NSHeight(contentFrame) - NSHeight(tabFrame);

  if ([self hasTabStrip]) {
    if ([self useVerticalTabs]) {
      // No top tabstrip so remove the tabContentArea offset.
      tabFrame.size.height = contentFrame.size.height;
      [tabContentArea_ setFrame:tabFrame];
      [self addSideTabStripToWindow];
    } else {
      [self addTopTabStripToWindow];
    }
  } else {
    // No top tabstrip so remove the tabContentArea offset.
    tabFrame.size.height = contentFrame.size.height;
    [tabContentArea_ setFrame:tabFrame];
  }
}

// Toggles from one display mode of the tab strip to another. Will automatically
// call -layoutSubviews to reposition other content.
- (void)toggleTabStripDisplayMode {
  // Adjust the size of the tab contents to either use more or less space,
  // depending on the direction of the toggle. This needs to be done prior to
  // adding back in the top tab strip as its position is based off the MaxY
  // of the tab content area.
  BOOL useVertical = [self useVerticalTabs];
  NSRect tabContentsFrame = [tabContentArea_ frame];
  tabContentsFrame.size.height += useVertical ?
      contentAreaHeightDelta_ : -contentAreaHeightDelta_;
  [tabContentArea_ setFrame:tabContentsFrame];

  if (useVertical) {
    // Remove the top tab strip and add the sidebar in.
    [topTabStripView_ removeFromSuperview];
    [self addSideTabStripToWindow];
  } else {
    // Remove the side tab strip and add the top tab strip as a sibling of the
    // window's content area.
    [sideTabStripView_ removeFromSuperview];
    NSRect tabContentsFrame = [tabContentArea_ frame];
    tabContentsFrame.size.height -= contentAreaHeightDelta_;
    [tabContentArea_ setFrame:tabContentsFrame];
    [self addTopTabStripToWindow];
  }

  [self layoutSubviews];
}

// Return the appropriate tab strip based on whether or not side tabs are
// enabled.
- (CTTabStripView*)tabStripView {
  if ([self useVerticalTabs])
    return sideTabStripView_;
  return topTabStripView_;
}

- (void)removeOverlay {
  if (closeDeferred_) {
    // See comment in BrowserWindowCocoa::Close() about orderOut:.
    [[self window] orderOut:self];
    [[self window] performClose:self];  // Autoreleases the controller.
  }
  [self setUseOverlay:NO];
}

- (void)showOverlay {
  [self setUseOverlay:YES];
}

// if |useOverlay| is true, we're moving views into the overlay's content
// area. If false, we're moving out of the overlay back into the window's
// content.
- (void)moveViewsBetweenWindowAndOverlay:(BOOL)useOverlay {
  if (useOverlay) {
    [[[overlayWindow_ contentView] superview] addSubview:[self tabStripView]];
    // Add the original window's content view as a subview of the overlay
    // window's content view.  We cannot simply use setContentView: here because
    // the overlay window has a different content size (due to it being
    // borderless).
    [[overlayWindow_ contentView] addSubview:cachedContentView_];
  } else {
    [[self window] setContentView:cachedContentView_];
    // The CTTabStripView always needs to be in front of the window's content
    // view and therefore it should always be added after the content view is
    // set.
    [[[[self window] contentView] superview] addSubview:[self tabStripView]];
    [[[[self window] contentView] superview] updateTrackingAreas];
  }
}

-(void)willStartTearingTab {
}

-(void)willEndTearingTab {
}

-(void)didEndTearingTab {
}

// If |useOverlay| is YES, creates a new overlay window and puts the tab strip
// and the content area inside of it. This allows it to have a different opacity
// from the title bar. If NO, returns everything to the previous state and
// destroys the overlay window until it's needed again. The tab strip and window
// contents are returned to the original window.
- (void)setUseOverlay:(BOOL)useOverlay {
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(removeOverlay)
                                             object:nil];
  NSWindow* window = [self window];
  if (useOverlay && !overlayWindow_) {
    assert(!cachedContentView_);
    overlayWindow_ = [[TabWindowOverlayWindow alloc]
                         initWithContentRect:[window frame]
                                   styleMask:NSBorderlessWindowMask
                                     backing:NSBackingStoreBuffered
                                       defer:YES];
    [overlayWindow_ setTitle:@"overlay"];
    [overlayWindow_ setBackgroundColor:[NSColor clearColor]];
    [overlayWindow_ setOpaque:NO];
    [overlayWindow_ setDelegate:self];
    cachedContentView_ = [window contentView];
    [window addChildWindow:overlayWindow_ ordered:NSWindowAbove];
    [self moveViewsBetweenWindowAndOverlay:useOverlay];
    [overlayWindow_ orderFront:nil];
  } else if (!useOverlay && overlayWindow_) {
    assert(cachedContentView_);
    [overlayWindow_ setDelegate:nil];
    [window setDelegate:nil];
    [window setContentView:cachedContentView_];
    [self moveViewsBetweenWindowAndOverlay:useOverlay];
    // When the last tab of a window is dragged to another window,
    // the following throws the (silent) exception:
    // "_newFirstResponderAfterResigining is not a valid message outside
    // of a responder's implementation of -resignFirstResponder."
    // This prevents the execution of the following crucial
    // commands and keeps the overlay window alive for the lifetime
    // of the application. Even when all windows close in an application
    // with -applicationShouldTerminateAfterLastWindowClosed returning YES,
    // the application will not terminate. For now, we let the user take
    // care of assigning first responder.
    //[window makeFirstResponder:cachedContentView_];
    [window display];
    [window removeChildWindow:overlayWindow_];
    [overlayWindow_ orderOut:nil];
    [overlayWindow_ release];
    overlayWindow_ = nil;
    cachedContentView_ = nil;
  } else {
    NOTREACHED();
  }
}

- (NSWindow*)overlayWindow {
  return overlayWindow_;
}

- (BOOL)shouldConstrainFrameRect {
  // If we currently have an overlay window, do not attempt to change the
  // window's size, as our overlay window doesn't know how to resize properly.
  return overlayWindow_ == nil;
}

- (BOOL)canReceiveFrom:(CTTabWindowController*)source {
  // subclass must implement
  NOTIMPLEMENTED();
  return NO;
}

- (void)moveTabView:(NSView*)view
     fromController:(CTTabWindowController*)dragController {
  NOTIMPLEMENTED();
}

- (NSView*)selectedTabView {
  NOTIMPLEMENTED();
  return nil;
}

- (void)layoutTabs {
  // subclass must implement
  NOTIMPLEMENTED();
}

- (CTTabWindowController*)detachTabToNewWindow:(CTTabView*)tabView {
  // subclass must implement
  NOTIMPLEMENTED();
  return NULL;
}

- (void)insertPlaceholderForTab:(CTTabView*)tab
                          frame:(NSRect)frame
                  yStretchiness:(CGFloat)yStretchiness {
  self.showsNewTabButton = NO;
}

- (void)removePlaceholder {
  if (didShowNewTabButtonBeforeTemporalAction_)
    self.showsNewTabButton = YES;
}

- (BOOL)tabDraggingAllowed {
  return YES;
}

- (BOOL)tabTearingAllowed {
  return YES;
}

- (BOOL)windowMovementAllowed {
  return YES;
}

- (BOOL)isTabFullyVisible:(CTTabView*)tab {
  // Subclasses should implement this, but it's not necessary.
  return YES;
}

- (void)setShowsNewTabButton:(BOOL)show {
  // subclass must implement
  NOTIMPLEMENTED();
}

- (BOOL)showsNewTabButton {
  // subclass must implement
  NOTIMPLEMENTED();
}


- (void)detachTabView:(NSView*)view {
  // subclass must implement
  NOTIMPLEMENTED();
}

- (NSInteger)numberOfTabs {
  // subclass must implement
  NOTIMPLEMENTED();
  return 0;
}

- (BOOL)hasLiveTabs {
  // subclass must implement
  NOTIMPLEMENTED();
  return NO;
}

- (NSString*)selectedTabTitle {
  // subclass must implement
  NOTIMPLEMENTED();
  return @"";
}

- (BOOL)hasTabStrip {
  // Subclasses should implement this.
  NOTIMPLEMENTED();
  return YES;
}

- (BOOL)useVerticalTabs {
  // Subclasses should implement this.
  NOTIMPLEMENTED();
  return NO;
}

- (BOOL)isTabDraggable:(NSView*)tabView {
  return ![lockedTabs_ containsObject:tabView];
}

- (void)setTab:(NSView*)tabView isDraggable:(BOOL)draggable {
  if (draggable)
    [lockedTabs_ removeObject:tabView];
  else
    [lockedTabs_ addObject:tabView];
}

// Tell the window that it needs to call performClose: as soon as the current
// drag is complete. This prevents a window (and its overlay) from going away
// during a drag.
- (void)deferPerformClose {
  closeDeferred_ = YES;
}

// Called when the size of the window content area has changed. Override to
// position specific views. Base class implementation does nothing.
- (void)layoutSubviews {
  NOTIMPLEMENTED();
}

@end

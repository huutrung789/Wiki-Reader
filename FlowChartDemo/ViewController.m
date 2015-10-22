//
//  ViewController.m
//  FlowChartDemo
//
//  Created by HuuTrung on 10/21/15.
//  Copyright © 2015 LivepassVN. All rights reserved.
//

#import "ViewController.h"
#import "ATPhysicsDebugView.h"

#import "ATPhysics.h"
#import "ATSpring.h"
#import "ATParticle.h"
#import "ATEnergy.h"

#import <dispatch/dispatch.h>
#import <QuartzCore/QuartzCore.h>

#define kTimerInterval 0.05
@interface ViewController () {
    NSInteger numOfNode;
    ATPhysics *physics;
    
    dispatch_source_t   _timer;
    NSInteger           _counter;
    BOOL                _running;
    NSMutableArray *arrayAllNode;
    NSMutableArray *arrayAllParticle;
}

@property (strong, nonatomic) IBOutlet ATPhysicsDebugView *mainView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    numOfNode = 0;
    physics = [[ATPhysics alloc] initWithDeltaTime:0.02 stiffness:1000.0 repulsion:600.0 friction:0.5];
    physics.gravity = NO;
    self.mainView.physics = physics;
    self.mainView.debugDrawing = YES;
    arrayAllNode = [NSMutableArray new];
    arrayAllParticle = [NSMutableArray new];
    
    physics.theta = 0.0;
    self.mainView.debugDrawing = NO;
    _running = NO;
}

- (void) viewDidUnload
{
    // Depricated in iOS 6.0  -  This method is never called.
    
    // This code remains until the best place for it is found or testing shows
    // it is not required.
    BOOL timerInitialized = (_timer != nil);
    if ( timerInitialized ) {
        dispatch_source_cancel(_timer);
        dispatch_resume(_timer);
    }
    
    [super viewDidUnload];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)touchAddNode:(id)sender {
    NSMutableArray *arrayParticle = [NSMutableArray new];
    CGPoint pos = CGPointMake(0.3, 0.3);
    for (NSInteger i = 0; i < 7; i++) {
        NSString *name = [NSString stringWithFormat:@"Node %d",i];
        ATParticle *particle = [[ATParticle alloc] initWithName:name mass:1.0f position:pos fixed:NO];
        [physics addParticle:particle];
        [arrayParticle addObject:particle];
        
        UIView *viewNode = [[UIView alloc] initWithFrame:CGRectMake(self.mainView.center.x + i*10, self.mainView.center.y + i*10, 50, 50)];
        viewNode.layer.cornerRadius = 3.0f;
        viewNode.layer.borderColor = [UIColor blackColor].CGColor;
        viewNode.layer.borderWidth = 2.0f;
        [self addGestureToView:viewNode];
        [self.mainView addSubview:viewNode];
        
        particle.position =  [self fromScreen:viewNode.center];
        
        [arrayAllNode addObject:viewNode];
        [arrayAllParticle addObject:particle];
    }
    
    for (int i=0; i<7; i++) {
        ATParticle *partile1 = arrayParticle[i];
        ATParticle *particle2;
        if (i<6) {
            particle2 = arrayParticle[i+1];
            ATSpring *spring = [[ATSpring alloc] initWithSource:partile1 target:particle2 length:1.0];
            [physics addSpring:spring];
        }
    }
    
    numOfNode += 7;
}

- (void) addGestureToView:(UIView*)view{
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(performPanGesture:)];
    [pan setMaximumNumberOfTouches:2];
    [pan setDelegate:self];
    [view addGestureRecognizer:pan];
}

- (void) performPanGesture:(UIPanGestureRecognizer*)gestureRecognizer {
    UIView *piece = [gestureRecognizer view];
    
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan || [gestureRecognizer state] == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gestureRecognizer translationInView:[piece superview]];
        
        [piece setCenter:CGPointMake([piece center].x + translation.x, [piece center].y + translation.y)];
        [gestureRecognizer setTranslation:CGPointZero inView:[piece superview]];
    }
    
    [self start];
}


- (CGPoint) fromScreen:(CGPoint)p
{
    CGSize size = self.mainView.bounds.size;
    CGFloat midX = size.width / 2;
    CGFloat midY = size.height / 2;
    
    CGFloat scaleX = size.width / 10;
    CGFloat scaleY = size.height / 10;
    
    CGFloat sx  = (p.x - midX) / scaleX;
    CGFloat sy  = (p.y - midY) / scaleY ;
    
    return CGPointMake(sx, sy);
}

- (CGPoint) toScreen:(CGPoint)p
{
    CGSize size = self.mainView.bounds.size;
    CGFloat midX = size.width / 2;
    CGFloat midY = size.height / 2;
    
    CGFloat scaleX = size.width / 10;
    CGFloat scaleY = size.height / 10;
    
    CGFloat sx  = (p.x * scaleX) + midX;
    CGFloat sy  = (p.y * scaleY) + midY;
    
    return CGPointMake(sx, sy);
}

- (void) start {
    BOOL timerNotInitialized = !_timer;
    if ( timerNotInitialized ) {
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        // create our timer source
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        
        // set the time to fire
        dispatch_source_set_timer(_timer,
                                  dispatch_time(DISPATCH_TIME_NOW, kTimerInterval * NSEC_PER_SEC),
                                  kTimerInterval * NSEC_PER_SEC, (kTimerInterval * NSEC_PER_SEC) / 2.0);
        
        // Hey, let's actually do something when the timer fires!
        dispatch_source_set_event_handler(_timer, ^{
            //            NSLog(@"WATCHDOG: task took longer than %f seconds",
            //                  kTimerInterval);
            
            // Call back to main thread (UI Thread) to update the text
            dispatch_async(dispatch_get_main_queue(), ^{
                [self stepPhysics];
            });
            
            // ensure we never fire again
            // dispatch_source_cancel(_timer);
            
            // pause the timer
            // dispatch_suspend(_timer);
        });
    }
    for (int i=0; i<arrayAllParticle.count; i++) {
        ATParticle *particle = arrayAllParticle[i];
        UIView *view = arrayAllNode[i];
        particle.position = [self fromScreen:view.center];
    }
    
    if (_running == NO) {
        _running = YES;
        // now that our timer is all set to go, start it
        dispatch_resume(_timer);
    }
}

-  (void) stepPhysics{
    for (int i=0; i<arrayAllParticle.count; i++) {
        ATParticle *particle = arrayAllParticle[i];
        UIView *view = arrayAllNode[i];
        view.center = [self toScreen:particle.position];
    }
}

@end

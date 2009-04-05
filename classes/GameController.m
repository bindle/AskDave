/*
 *  AskDave
 *  Copyright (C) 2009 David M. Syzdek <syzdek@bindlebinaries.net>.
 *
 *  @BINDLEBINARIES_FOSS_LICENSE_HEADER_START@
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License Version 2 as
 *  published by the Free Software Foundation.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 *
 *  @BINDLEBINARIES_FOSS_LICENSE_HEADER_END@
 */
/**
 *  @file classes/GameController.m controls the game board
 */

///////////////
//           //
//  Headers  //
//           //
///////////////

#import "GameController.h"
#import <AudioToolbox/AudioToolbox.h>

// Constant for the number of times per second (Hertz) to sample acceleration.
#define kAccelerometerFrequency     10
#define kTimerFrequency             10.0
#define kAccelerometerForce         .75
#define kAccelerometerToDegrees     15
#define kSpeedMagnitude             100
#define kDurationMagnitude          0.2
#define kMaxDuration                10.0


CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
CGFloat RadiansToDegrees(CGFloat radians) {return radians * 180/M_PI;};

@implementation GameController

@synthesize hasFliped;
@synthesize x;
@synthesize y;
@synthesize z;
@synthesize oldX;
@synthesize oldY;
@synthesize oldZ;
@synthesize delegate;
@synthesize forceDataX;
@synthesize forceDataY;
@synthesize forceDataZ;

@synthesize background;
@synthesize backgroundView;
@synthesize foreground;
@synthesize foregroundView;
@synthesize board;
@synthesize boardView;
@synthesize messages;
@synthesize messageView;

@synthesize defaults;


// Implement loadView if you want to create a view hierarchy programmatically
- (void)loadView
{
   CGRect              frame;
   UIView            * localView;
   UIButton          * localButton;
   UIImageView       * localImageView;
   //NSString          * path;
   NSAutoreleasePool * pool;
#ifdef DEBUG
   UILabel           * localLabel;
#endif
   
   pool = [[NSAutoreleasePool alloc] init];

   //path = [[NSBundle mainBundle] pathForResource:@"chimes" ofType:@"wav"];
   //AudioServicesCreateSystemSoundID((CFURLRef)[NSURL fileURLWithPath:path], &chimes);

   // load view
   localView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
   self.view = localView;
   [localView release];

   // loads background
   frame                      = CGRectMake(0.0, 0.0, 320, 480);
   if (self.background)
   {
      frame.size.width           = self.background.size.width;
      frame.size.height          = self.background.size.height;
      frame.origin.x             = 0 - ((self.background.size.width  - 320)/2);
      frame.origin.y             = 0 - ((self.background.size.height - 480)/2);
   };
   localImageView             = [[UIImageView alloc] initWithFrame:frame];
   localImageView.image       = self.background;
   self.backgroundView        = localImageView;
   [self.view addSubview:localImageView];
   [localImageView release];

   // loads foreground
   frame                      = CGRectMake(0.0, 0.0, 320, 480);
   localImageView             = [[UIImageView alloc] initWithFrame:frame];
   localImageView.image       = self.foreground;
   self.foregroundView        = localImageView;
   [self.view addSubview:localImageView];
   [localImageView release];

   // loads message board
   frame                      = CGRectMake(0.0, 0.0, 320, 480);
   localImageView             = [[UIImageView alloc] initWithFrame:frame];
   localImageView.image       = self.board;
   self.boardView             = localImageView;
   [self.view addSubview:localImageView];
   [localImageView release];

   // loads message
   frame                      = CGRectMake(0.0, 0.0, 320, 480);
   localImageView             = [[UIImageView alloc] initWithFrame:frame];
   localImageView.image       = Nil;
   self.messageView           = localImageView;
   [self.view addSubview:localImageView];
   [localImageView release];
   
   // Add 'i' button
   localButton       = [UIButton buttonWithType:UIButtonTypeInfoLight];
   localButton.frame = CGRectMake(320-40, 480-40, 40, 40);
   [localButton addTarget:delegate action:@selector(showMenuView:) forControlEvents:UIControlEventTouchUpInside];
   [self.view addSubview:localButton];
   
#ifdef DEBUG
   frame           = CGRectMake(20.0, 20.0, 280.0, 22.0);
   localLabel      = [[UILabel alloc] initWithFrame:frame];
   localLabel.font = [UIFont systemFontOfSize:17];
   localLabel.backgroundColor = [UIColor clearColor];
   self.forceDataX = localLabel;
   [localLabel release];
   [self.view addSubview:self.forceDataX];
   
   frame           = CGRectMake(20.0, 39.0, 280.0, 22.0);
   localLabel      = [[UILabel alloc] initWithFrame:frame];
   localLabel.font = [UIFont systemFontOfSize:17];
   localLabel.backgroundColor = [UIColor clearColor];
   self.forceDataY = localLabel;
   [localLabel release];
   [self.view addSubview:self.forceDataY];
   
   frame           = CGRectMake(20.0, 60.0, 280.0, 22.0);
   localLabel      = [[UILabel alloc] initWithFrame:frame];
   localLabel.font = [UIFont systemFontOfSize:17];
   localLabel.backgroundColor = [UIColor clearColor];
   self.forceDataZ = localLabel;
   [localLabel release];
   [self.view addSubview:self.forceDataZ];
#endif

   self.oldX = 4;
   self.oldY = 4;
   self.oldZ = 4;
   
   [pool release];
   
   return;
}


// UIAccelerometerDelegate method, called when the device accelerates.
- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
   if ([self.defaults boolForKey:@"shake"])
      [self accelerometerShake:accelerometer didAccelerate:acceleration];
   else
      [self accelerometerFlip:accelerometer didAccelerate:acceleration];
   return;
}


// UIAccelerometerDelegate method, called when the device accelerates.
- (void)accelerometerFlip:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
   NSAutoreleasePool * pool;
   
   pool = [[NSAutoreleasePool alloc] init];

   x = acceleration.x;
   y = acceleration.y;
   z = acceleration.z;
   
#ifdef DEBUG
   forceDataX.text = [NSString stringWithFormat:@"X: %+1.30f", x];
   forceDataY.text = [NSString stringWithFormat:@"Y: %+1.30f", y];
   forceDataZ.text = [NSString stringWithFormat:@"Z: %+1.30f", z];
#endif

   if (z > 0.7)
   {
      hasFliped = YES;
      self.messageView.image = Nil;
   };
   if ((z < 0.0) && (hasFliped))
   {
      hasFliped                  = NO;
      [self rollBall:nil];
   };
   
   [pool release];
   return;
}


// UIAccelerometerDelegate method, called when the device accelerates.
- (void)accelerometerShake:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
   float               diffX;
   float               diffY;
   float               diffZ;
   NSAutoreleasePool * pool;

   // grabs current readings
   self.x = acceleration.x;
   self.y = acceleration.y;
   self.z = acceleration.z;
   
   // if this is the first reading, save state and exit
   if ((self.oldX > 3) || (self.oldY > 3) || (self.oldZ > 3))
   {
      self.oldX = self.x;
      self.oldY = self.y;
      self.oldZ = self.z;
      return;
   }
   
   diffX = fabsf(self.x - self.oldX);
   diffY = fabsf(self.y - self.oldY);
   diffZ = fabsf(self.z - self.oldZ);

   pool = [[NSAutoreleasePool alloc] init];
   
#ifdef DEBUG
   forceDataX.text = [NSString stringWithFormat:@"X: %+1.30f", diffX];
   forceDataY.text = [NSString stringWithFormat:@"Y: %+1.30f", diffY];
   forceDataZ.text = [NSString stringWithFormat:@"Z: %+1.30f", diffZ];
#endif

   //if (z > 0.3)
   //   [message setText:@""];
   if ((diffX > 1.0) || (diffY > 1.0) || (diffZ > 1.0))
   {
      self.hasFliped             = YES;
      self.messageView.image     = Nil;
   }
   else if (((diffX < 0.1) || (diffY < 0.1) || (diffZ < 0.1)) && (hasFliped))
   {
      hasFliped                  = NO;
      [self rollBall:nil];
   };
   
   self.oldX = self.x;
   self.oldY = self.y;
   self.oldZ = self.z;
   
   [pool release];
   
   return;
}


- (IBAction) rollBall:(NSString *)newMessage
{
   NSUInteger   msg_count = [self.messages count];
   NSUInteger   msg_index = random() % msg_count;
   self.messageView.image = [self.messages objectAtIndex:msg_index];

   if ([self.defaults boolForKey:@"vibrate"])
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
   if ([self.defaults boolForKey:@"sound"])
      AudioServicesPlaySystemSound(chimes);

   self.messageView.hidden = NO;

   //if (newMessage)
   //   self.message.text = newMessage;
      
  return;
};



// If you need to do additional setup after loading the view, override viewDidLoad.
- (void)viewDidLoad
{
   // loads accelerometer
   [[UIAccelerometer sharedAccelerometer] setUpdateInterval:(1.0 / kAccelerometerFrequency)];
   [[UIAccelerometer sharedAccelerometer] setDelegate:self];

   [self animationDidStop:Nil finished:YES];

   return;
}


- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
   if (!(flag))
      return;

   // cancels existing rotating backgrounds
   [self.backgroundView.layer removeAllAnimations];

   CABasicAnimation * myAnimation  = [CABasicAnimation animation];
   myAnimation.delegate            = self;
   myAnimation.keyPath             = @"transform.rotation.z";
   myAnimation.fromValue           = [NSNumber numberWithFloat:DegreesToRadians(0)];
   myAnimation.toValue             = [NSNumber numberWithFloat:DegreesToRadians(25)];
   myAnimation.duration            = 1;
   myAnimation.removedOnCompletion = NO;
   // leaves presentation layer in final state; preventing snap-back to original state
   myAnimation.fillMode = kCAFillModeBoth;
   myAnimation.autoreverses = YES; 
   myAnimation.repeatCount = 5;
   myAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

   [self.backgroundView.layer addAnimation:myAnimation forKey:@"rotateAnimation"];
   return;
}



- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
   switch(interfaceOrientation)
   {
      case UIInterfaceOrientationPortrait:
      case UIInterfaceOrientationPortraitUpsideDown:
         return(YES);
      default:
         return(NO);
   };
	return (NO);
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}


- (void)dealloc
{
   self.forceDataX      = nil;
   self.forceDataY      = nil;
   self.forceDataZ      = nil;

   self.background      = nil;
   self.backgroundView  = nil;
   self.foreground      = nil;
   self.foregroundView  = nil;
   self.board           = nil;
   self.boardView       = nil;
   self.messages        = nil;
   self.messageView     = nil;

   self.defaults;
   AudioServicesDisposeSystemSoundID(chimes);
	[super dealloc];
}


@end

/* end of source */
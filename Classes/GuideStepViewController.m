    //
//  GuideStepViewController.m
//  iFixit
//
//  Created by David Patierno on 8/7/10.
//  Copyright 2010 iFixit. All rights reserved.
//

#import "GuideStepViewController.h"
#import "GuideImageViewController.h"
#import "GuideStep.h"
#import "GuideImage.h"


@implementation GuideStepViewController

@synthesize delegate, step, titleLabel, mainImage, imageSpinner, textSpinner, webView, imageVC, image;
@synthesize image1, image2, image3, numImagesLoaded, bigImages;

static CGRect frameView;

// Load the view nib and initialize the pageNumber ivar.
+ (id)initWithStep:(GuideStep *)step {
	frameView = CGRectMake(0.0f,    0.0f, 1024.0f, 768.0f);
	
	GuideStepViewController *vc = [[GuideStepViewController alloc] initWithNibName:@"GuideStepView" bundle:nil];

	vc.step = step;
	vc.numImagesLoaded = 0;
    vc.bigImages = [NSMutableArray array];
    
    return [vc autorelease];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
		
	NSString *stepTitle = [NSString stringWithFormat:@"Step %d", step.number];
	if (![step.title isEqual:@""])
		stepTitle = [NSString stringWithFormat:@"%@ - %@", stepTitle, step.title];
	
	[titleLabel setText:stepTitle];

    // Load the step contents as HTML.
    NSString *header = @"<html><head><style>EXTERNALSTYLESGOHERE</style></head><body><ul>";
    NSString *footer = @"</ul></body></html>";
    NSString *styles = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"guideStepStyles" ofType:@"css"] encoding:NSUTF8StringEncoding error:nil];
    
    // Insert external style data
    header = [header stringByReplacingOccurrencesOfString:@"EXTERNALSTYLESGOHERE" withString:styles];
   
    NSMutableString *body = [NSMutableString stringWithString:@""];
    for (GuideStepLine *line in step.lines) {
        NSString *icon = @"";
        
        if ([line.bullet isEqual:@"icon_note"] || [line.bullet isEqual:@"icon_reminder"] || [line.bullet isEqual:@"icon_caution"]) {
            icon = [NSString stringWithFormat:@"<div class=\"bulletIcon bullet_%@\"></div>", line.bullet];
            line.bullet = @"black";
        }
        
       [body appendFormat:@"<li class=\"l_%d\"><div class=\"bullet bullet_%@\"></div>%@<p>%@</p><div style=\"clear: both\"></div></li>\n", line.level, line.bullet, icon, line.text];
    }
       
    NSString *html = [NSString stringWithFormat:@"%@%@%@", header, body, footer];
    [webView loadHTMLString:html baseURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", IFIXIT_HOST]]];
   	webView.backgroundColor = [UIColor blackColor];
    
    // Disable bounce scrolling.
    for (id subview in webView.subviews)
        if ([[subview class] isSubclassOfClass:[UIScrollView class]])
            ((UIScrollView *)subview).bounces = NO;
}

- (void)startImageDownloads {
    if ([step.images count] > numImagesLoaded)
        [[CachedImageLoader sharedImageLoader] addClientToDownloadQueue:self];
}

- (IBAction)changeImage:(UIButton *)button {
    if ([button isEqual:image1])
        self.image = [bigImages objectAtIndex:0];
    else if ([button isEqual:image2])
        self.image = [bigImages objectAtIndex:1];
    else if ([button isEqual:image3])
        self.image = [bigImages objectAtIndex:2];
    
    [mainImage setBackgroundImage:self.image forState:UIControlStateNormal];
}


- (NSURLRequest *)request {
    if (numImagesLoaded >= [step.images count])
        return nil;

    return [NSURLRequest requestWithURL:[[step.images objectAtIndex:numImagesLoaded] URLForSize:@"large"]];
}
- (void)renderImage:(UIImage *)theImage {
    numImagesLoaded++;
    
    // Save the large image.
    [bigImages addObject:theImage];
    
    // Load the small image thumbnail.
    // Use this instead of dispatch_async() for iOS 3.2 compatibility.
    [self performSelectorInBackground:@selector(loadSmallImage:) withObject:[NSNumber numberWithInt:numImagesLoaded-1]];
    
    // Use this instead of dispatch_async() for iOS 3.2 compatibility.
    [self performSelectorOnMainThread:@selector(setMainAndLoadNext:) withObject:theImage waitUntilDone:YES];
}

- (void)setMainAndLoadNext:(UIImage *)theImage {
    // First image, set the main.
    if (numImagesLoaded == 1) {
        self.image = theImage;
        [imageSpinner stopAnimating];
        [mainImage setBackgroundImage:image forState:UIControlStateNormal];
        mainImage.hidden = NO;
    }
    
    // Load the next image.
    if ([step.images count] > numImagesLoaded)
        [[CachedImageLoader sharedImageLoader] addClientToDownloadQueue:self];
}

- (void)loadSmallImage:(NSNumber *)index {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSURLRequest *thumbRequest = [NSURLRequest requestWithURL:[[step.images objectAtIndex:[index intValue]] URLForSize:@"thumbnail"]];
    NSData *data = [NSURLConnection sendSynchronousRequest:thumbRequest
                                         returningResponse:nil
                                                     error:nil];
    
    UIImage *thumbnailImage = [UIImage imageWithData:data];

    NSArray *imageAndIndex = [NSArray arrayWithObjects:thumbnailImage, index, nil];
    
    // Use this instead of dispatch_async() for iOS 3.2 compatibility.
    [self performSelectorOnMainThread:@selector(setSmallImage:) withObject:imageAndIndex waitUntilDone:YES];
    
    [pool drain];
}
- (void)setSmallImage:(NSArray *)imageAndIndex {
    
    UIImage *thumbnailImage = [imageAndIndex objectAtIndex:0];
    NSNumber *index = [imageAndIndex objectAtIndex:1];
    
    // Which image? 1,2,3
    UIButton *imageButton;
    switch ([index intValue]) {
        case 0:
            imageButton = image1;
            break;
        case 1:
            imageButton = image2;
            break;
        case 2:
            imageButton = image3;
            break;
    }
    
    [imageButton setBackgroundImage:thumbnailImage forState:UIControlStateNormal];
    
    // Show the thumbnails.
    if (numImagesLoaded > 1) {
        image1.hidden = NO;
        image2.hidden = NO;
    }
    
    if (numImagesLoaded == 3)
        image3.hidden = NO;   
    
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {

   if (navigationType != UIWebViewNavigationTypeLinkClicked)
      return YES;
   
   // Load all URLs in Safari.
   [[UIApplication sharedApplication] openURL:[request URL]];
   return NO;
   
}

// Because the web view has a white background, it starts hidden.
// After the content is loaded, we wait a small amount of time before showing it to prevent flicker.
- (void)webViewDidFinishLoad:(UIWebView *)webView {
	[self performSelector:@selector(showWebView:) withObject:nil afterDelay:0.3];
}
- (void)showWebView:(id)sender {
	[textSpinner stopAnimating];
	webView.hidden = NO;	
}

- (IBAction)zoomImage:(id)sender {
   	
	// Create the image view controller and add it to the view hierarchy.
	self.imageVC = [GuideImageViewController initWithUIImage:image];
	imageVC.delegate = self;
	[[delegate view] addSubview:imageVC.view];

	// Set the position and hide it.
	imageVC.view.alpha = 0;
	imageVC.view.frame = frameView;
	
	// Animate the button and fade in the image view
	[UIView beginAnimations:@"ImageView" context:nil];
	[UIView setAnimationDuration:0.25];
//	mainImage.transform = CGAffineTransformMakeScale(2,2);
	imageVC.view.alpha = 1;
	[UIView commitAnimations];
   
}
- (void)hideGuideImage:(id)object {
	[UIView beginAnimations:@"ImageView" context:nil];
	[UIView setAnimationDuration:0.25];
	imageVC.view.alpha = 0;
//	mainImage.transform = CGAffineTransformMakeScale(1,1);
	[UIView commitAnimations];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overriden to allow any orientation.
    return YES;
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
   self.mainImage = nil;
}


- (void)dealloc {
    self.step = nil;
    self.image = nil;
    self.bigImages = nil;
   
    webView.delegate = nil;
    self.mainImage = nil;
   
    [super dealloc];
}


@end

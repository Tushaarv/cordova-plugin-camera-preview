#import "CameraRenderController.h"

@implementation CameraRenderController
@synthesize context = _context;

- (void)viewDidLoad
{
    [super viewDidLoad]; 

    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }

    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);

    self.ciContext = [CIContext contextWithEAGLContext:self.context]; 

    dispatch_async(self.sessionManager.sessionQueue, ^{
        AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
        if ([self.sessionManager.session canAddOutput:dataOutput])
        {
            [dataOutput setAlwaysDiscardsLateVideoFrames:YES];
            [dataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];   

            [dataOutput setSampleBufferDelegate:self queue:self.sessionManager.sessionQueue];

            [self.sessionManager.session addOutput:dataOutput];

            AVCaptureConnection *captureConnection = [dataOutput connectionWithMediaType:AVMediaTypeVideo];
            if ([captureConnection isVideoOrientationSupported]) {
                [captureConnection setVideoOrientation:(AVCaptureVideoOrientation)[self interfaceOrientation]];
            }
        }
    });
}

- (void)viewWillAppear:(BOOL)animated {
    dispatch_async(self.sessionManager.sessionQueue, ^{
      [self.sessionManager.session startRunning];
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    dispatch_async(self.sessionManager.sessionQueue, ^{
      [self.sessionManager.session stopRunning];
    });
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CIFilter *filter = [self.sessionManager ciFilter];

    CIImage *result;
    if (filter != nil) {
        [filter setValue:image forKey:kCIInputImageKey];
        result = [filter outputImage];
    } else {
        result = image;
    }

    CGFloat scale = [[UIScreen mainScreen] scale];
    CGRect dest = CGRectMake(0, 0, self.view.frame.size.width*scale, self.view.frame.size.height*scale);
    [self.ciContext drawImage:result inRect:dest fromRect:[image extent]];
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)viewDidUnload
{
    [super viewDidUnload];

    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc. that aren't in use.
}

- (BOOL)shouldAutorotate {
    return NO;
}

@end

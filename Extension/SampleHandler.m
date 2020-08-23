//
//  SampleHandler.m
//  ClairEye
//
//  Created by AmpleSky on 2020/3/31.
//  Copyright © 2020年 Facebook. All rights reserved.
//

#import "SampleHandler.h"
#import "NTESYUVConverter.h"
#import "NTESI420Frame.h"
#import "GCDAsyncSocket.h"
#import "NTESSocketPacket.h"
#import "NTESTPCircularBuffer.h"

@interface SampleHandler ()<GCDAsyncSocketDelegate>

@property (nonatomic, assign) CGFloat cropRate;
@property (nonatomic, assign) CGSize  targetSize;
@property (nonatomic, assign) NTESVideoPackOrientation orientation;

@property (nonatomic, copy) NSString *ip;
@property (nonatomic, copy) NSString *clientPort;
@property (nonatomic, copy) NSString *serverPort;
@property (nonatomic, strong) dispatch_queue_t videoQueue;
@property (nonatomic, assign) NSUInteger frameCount;
@property (nonatomic, assign) BOOL connected;
@property (nonatomic, strong) dispatch_source_t timer;

@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) NTESTPCircularBuffer *recvBuffer;

@end

@implementation SampleHandler
BOOL _enterBack = false;
static void Callback(CFNotificationCenterRef center,
                     void *observer,
                     CFStringRef name,
                     const void *object,
                     CFDictionaryRef userInfo)
{
  _enterBack = true;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
  _enterBack = false;
  });
 
}
BOOL _finish = false;
static void FinishCallback(CFNotificationCenterRef center,
                           void *observer,
                           CFStringRef name,
                           const void *object,
                           CFDictionaryRef userInfo)
{
  _finish = true;
  
}


- (void)dealloc {
  _connected = NO;
  
  if (_socket) {
    [_socket disconnect];
    _socket = nil;
    NTESTPCircularBufferCleanup(_recvBuffer);
  }
  
  if(_timer) {
    _timer = nil;
  }
}

- (instancetype)init {
  if(self = [super init]) {
    
    _targetSize = CGSizeMake(540, 960);
    _cropRate = 15;
    _orientation = NTESVideoPackOrientationPortrait;
    
    _ip = @"127.0.0.1";
    _serverPort = @"8999";
    _clientPort = [NSString stringWithFormat:@"%d", arc4random()%9999];
    _videoQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    CFStringRef name = CFSTR("customName");
    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center,
                                    (const void *)self,
                                    Callback,
                                    name,
                                    NULL,
                                    kCFNotificationDeliverImmediately);
    CFStringRef finishName = CFSTR("StopScreen");
    CFNotificationCenterRef finishCenter = CFNotificationCenterGetDarwinNotifyCenter();
  
    CFNotificationCenterAddObserver(finishCenter,
                                    (const void *)self,
                                    FinishCallback,
                                    finishName,
                                    NULL,
                                    kCFNotificationDeliverImmediately);
    

  }
  return self;
}


- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
  if (!self.connected) {
    [self.socket disconnect];
  }
  if (!self.socket.isConnected) {
    [self setupSocket];
  }
  
}

- (void)broadcastPaused {
//  if (self.connected) {
//    NSString * str =@"Paused";
//    NSData *data =[str dataUsingEncoding:NSUTF8StringEncoding];
//    [self.socket writeData:data withTimeout:5 tag:0];
//  }
}

- (void)broadcastResumed {
//  if (self.connected) {
//    NSString * str =@"Resumed";
//    NSData *data =[str dataUsingEncoding:NSUTF8StringEncoding];
//    [self.socket writeData:data withTimeout:5 tag:0];
//  }
}

- (void)broadcastFinished {
  if (self.connected) {
    NSString * str =@"Finish";
    NSData *data =[str dataUsingEncoding:NSUTF8StringEncoding];
    [self.socket writeData:data withTimeout:-1 tag:0];
  }
//  [self.socket disconnect];
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
  switch (sampleBufferType) {
    case RPSampleBufferTypeVideo:
    {
      if (!self.connected)
      {
        return;
      }
//      if(self.connected){
      
      if(_finish){
        NSError *error;
        if([UIDevice currentDevice].systemVersion.doubleValue >= 12 && [UIDevice currentDevice].systemVersion.doubleValue < 13){
          error = [NSError errorWithDomain:@"您停止了屏幕共享" code:-001 userInfo:@{}];
        }else{
          error = nil;
        }
        [self finishBroadcastWithError:error];
      }
      
      
      if( CMSampleBufferDataIsReady(sampleBuffer)){
        [self sendVideoBufferToHostApp:sampleBuffer];
      }

    }
      break;
    case RPSampleBufferTypeAudioApp:
      // Handle audio sample buffer for app audio
      break;
    case RPSampleBufferTypeAudioMic:
      // Handle audio sample buffer for mic audio
      break;
      
    default:
      break;
  }
}
#pragma mark - 处理分辨率切换等
- (void)onRecvData:(NSData *)data head:(NTESPacketHead *)head
{
  if (!data)
  {
    return;
  }
  
  switch (head->command_id)
  {
    case 1:
    {
      NSString *qualityStr = [NSString stringWithUTF8String:[data bytes]];
      int qualit = [qualityStr intValue];
      switch (qualit) {
        case 0:
          self.targetSize = CGSizeMake(480, 640);
          break;
        case 1:
          self.targetSize = CGSizeMake(144, 177);
          break;
        case 2:
          self.targetSize = CGSizeMake(288, 352);
          break;
        case 3:
          self.targetSize = CGSizeMake(320, 480);
          break;
        case 4:
          self.targetSize = CGSizeMake(375, 667);
          break;
        case 5:
          self.targetSize = CGSizeMake(414, 812);
          break;
        case 6:
          self.targetSize = CGSizeMake(414, 812);
          break;
        default:
          break;
      }
      NSLog(@"change target size %@", @(self.targetSize));
    }
      break;
    case 2:
      break;
    case 3:
    {
      NSString *orientationStr = [NSString stringWithUTF8String:[data bytes]];
      int orient = [orientationStr intValue];
      switch (orient) {
        case 0:
          self.orientation = NTESVideoPackOrientationPortrait;
          break;
        case 1:
          self.orientation = NTESVideoPackOrientationLandscapeLeft;
          break;
        case 2:
          self.orientation = NTESVideoPackOrientationPortraitUpsideDown;
          break;
        case 3:
          self.orientation = NTESVideoPackOrientationLandscapeRight;
          break;
        default:
          break;
      };
      NSLog(@"change orientation %@", @(self.orientation));
      
    }
      break;
    default:
      break;
  }
}



#pragma mark - Process
- (void)sendVideoBufferToHostApp:(CMSampleBufferRef)sampleBuffer {
  if (!self.socket)
  {
    return;
  }
  CFRetain(sampleBuffer);
  
  dispatch_async(self.videoQueue, ^{ // queue optimal
    @autoreleasepool {
      if (self.frameCount > 1000)
      {
        CFRelease(sampleBuffer);
        return;
      }
      self.frameCount ++ ;
      CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
      
      CFStringRef RPVideoSampleOrientationKeyRef = (__bridge CFStringRef)RPVideoSampleOrientationKey;
      NSNumber *orientation = (NSNumber *)CMGetAttachment(sampleBuffer, RPVideoSampleOrientationKeyRef,NULL);
      
       switch ([orientation integerValue]) {
         case 1:
           self.orientation = NTESVideoPackOrientationPortrait;
            break;
         case 6:
           self.orientation = NTESVideoPackOrientationLandscapeRight;
           break;
           
         case 8:
           self.orientation = NTESVideoPackOrientationLandscapeLeft;
           break;
         default:
           break;
       }
      // To data
      NTESI420Frame *videoFrame = nil;
      videoFrame = [NTESYUVConverter pixelBufferToI420:pixelBuffer
                                              withCrop:self.cropRate
                                            targetSize:self.targetSize
                                        andOrientation:self.orientation];
      CFRelease(sampleBuffer);
      // To Host App
      if (videoFrame){
          NSData *raw = [videoFrame bytes];
          //NSData *data = [NTESSocketPacket packetWithBuffer:raw];
          NSData *headerData = [NTESSocketPacket packetWithBuffer:raw];
          if (!_enterBack) {
            if (self.connected) {
              [self.socket writeData:headerData withTimeout:-1 tag:0];
              [self.socket writeData:raw withTimeout:-1 tag:0];
            }
          }
      }
      self.frameCount --;
    };
  });
}

- (NSData *)packetWithBuffer:(NSData *)rawData
{
  NSMutableData *mutableData = [NSMutableData data];
  @autoreleasepool {
    if (rawData.length == 0)
    {
      return NULL;
    }
    
    size_t size = rawData.length;
    void *data = malloc(sizeof(NTESPacketHead));
    NTESPacketHead *head = (NTESPacketHead *)malloc(sizeof(NTESPacketHead));
    head->version = 1;
    head->command_id = 0;
    head->service_id = 0;
    head->serial_id = 0;
    head->data_len = (uint32_t)size;
    
    size_t headSize = sizeof(NTESPacketHead);
    memcpy(data, head, headSize);
    NSData *headData = [NSData dataWithBytes:data length:headSize];
    [mutableData appendData:headData];
    [mutableData appendData:rawData];
    
    free(data);
    free(head);
  }
  return [mutableData copy];
}

- (NSData *)packetWithBuffer:(const void *)buffer
                        size:(size_t)size
                  packetSize:(size_t *)packetSize
{
  if (0 == size)
  {
    return NULL;
  }
  
  void *data = malloc(sizeof(NTESPacketHead) + size);
  NTESPacketHead *head = (NTESPacketHead *)malloc(sizeof(NTESPacketHead));
  head->version = 1;
  head->command_id = 0;
  head->service_id = 0;
  head->serial_id = 0;
  head->data_len = (uint32_t)size;
  
  size_t headSize = sizeof(NTESPacketHead);
  *packetSize = size + headSize;
  memcpy(data, head, headSize);
  memcpy(data + headSize, buffer, size);
  
  
  NSData *result = [NSData dataWithBytes:data length:*packetSize];
  
  free(head);
  free(data);
  return result;
}

#pragma mark - Socket

- (void)setupSocket
{
  _recvBuffer = (NTESTPCircularBuffer *)malloc(sizeof(NTESTPCircularBuffer)); // 需要释放
  NTESTPCircularBufferInit(_recvBuffer, kRecvBufferMaxSize);
  self.queue = dispatch_queue_create("com.netease.edu.rp.client", DISPATCH_QUEUE_SERIAL);
  self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queue];
  //    self.socket.IPv6Enabled = NO;
  //    [self.socket connectToUrl:[NSURL fileURLWithPath:serverURL] withTimeout:5 error:nil];
  NSError *error;
  [self.socket connectToHost:_ip onPort:8999 error:&error];
  [self.socket readDataWithTimeout:-1 tag:0];
  NSLog(@"setupSocket:%@",error);
  if (error == nil)
  {
    NSLog(@"====开启成功");
  }
  else
  {
    NSLog(@"=====开启失败");
  }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToUrl:(NSURL *)url
{
  [self.socket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
  if (self.connected) {
    NSString * str =@"Start";
    NSData *data =[str dataUsingEncoding:NSUTF8StringEncoding];
    [self.socket writeData:data withTimeout:15 tag:0];
  }
  [self.socket readDataWithTimeout:-1 tag:0];
  self.connected = YES;
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
  
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
  NTESTPCircularBufferProduceBytes(self.recvBuffer, data.bytes, (int32_t)data.length);
  [self handleRecvBuffer];
  [sock readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
  self.connected = NO;
  [self.socket disconnect];
  self.socket = nil;
  [self setupSocket];
  [self.socket readDataWithTimeout:-1 tag:0];
}

- (void)handleRecvBuffer {
  if (!self.socket)
  {
    return;
  }
  
  int32_t availableBytes = 0;
  void * buffer = NTESTPCircularBufferTail(self.recvBuffer, &availableBytes);
  int32_t headSize = sizeof(NTESPacketHead);
  
  if (availableBytes <= headSize)
  {
    return;
  }
  
  NTESPacketHead head;
  memset(&head, 0, sizeof(head));
  memcpy(&head, buffer, headSize);
  uint64_t dataLen = head.data_len;
  
  if(dataLen > availableBytes - headSize && dataLen >0) {
    return;
  }
  
  void *data = malloc(dataLen);
  memset(data, 0, dataLen);
  memcpy(data, buffer + headSize, dataLen);
  NTESTPCircularBufferConsume(self.recvBuffer, (int32_t)(headSize+dataLen));
  
  
  if([self respondsToSelector:@selector(onRecvData:head:)]) {
    @autoreleasepool {
      [self onRecvData:[NSData dataWithBytes:data length:dataLen] head:&head];
    };
  }
  
  free(data);
  
  if (availableBytes - headSize - dataLen >= headSize)
  {
    [self handleRecvBuffer];
  }
}
@end


//
//  ViewController.h
//  ShareScreeen
//
//  Created by 陈强 on 2020/8/16.
//  Copyright © 2020 MKMooc.shanghai.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ReplayKit/ReplayKit.h>
#import "GCDAsyncSocket.h"
#import "NTESTPCircularBuffer.h"
#import "NTESSocketPacket.h"
#import "NTESI420Frame.h"
#import "NTESYUVConverter.h"

@interface ViewController : UIViewController
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSMutableArray *sockets;
@property (nonatomic, assign) NTESTPCircularBuffer *recvBuffer;
@property (nonatomic, strong)NSTimer        *SocketTimer;
@property (nonatomic, assign)NSInteger        rotation;


@end


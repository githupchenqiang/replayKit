//
//  AppDelegate.h
//  ShareScreeen
//
//  Created by 陈强 on 2020/8/16.
//  Copyright © 2020 MKMooc.shanghai.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (readonly, strong) NSPersistentCloudKitContainer *persistentContainer;

- (void)saveContext;


@end


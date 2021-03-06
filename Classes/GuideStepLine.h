//
//  GuideStepLine.h
//  iFixit
//
//  Created by David Patierno on 8/7/10.
//  Copyright 2010 iFixit. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface GuideStepLine : NSObject {
	NSInteger lineid;
	NSInteger level;
	NSString *bullet;
	NSString *text;
}

@property (nonatomic) NSInteger lineid;
@property (nonatomic) NSInteger level;
@property (nonatomic, retain) NSString *bullet;
@property (nonatomic, retain) NSString *text;

+ (GuideStepLine *)guideStepLineWithDictionary:(NSDictionary *)dict;

@end

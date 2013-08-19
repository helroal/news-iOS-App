//
//  FeedListController.m
//  iOCNews
//

/************************************************************************
 
 Copyright 2012-2013 Peter Hedlund peter.hedlund@me.com
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 *************************************************************************/

#import "OCFeedListController.h"
#import "IIViewDeckController.h"
#import "OCFeedCell.h"
#import "AFNetworking.h"
#import "OCAPIClient.h"
#import "OCLoginController.h"
#import "TSMessage.h"
#import "TransparentToolbar.h"
#import "OCNewsHelper.h"
#import "Feed.h"
#import "FeedExtra.h"

@interface OCFeedListController () {
    int parserCount;
    int currentIndex;
    BOOL haveSyncData;
    PopoverView *_popover;
}

- (void) updateItems;
- (void) emailSupport:(NSNotification*)n;

@end

@implementation OCFeedListController

@synthesize addBarButtonItem;
@synthesize infoBarButtonItem;
@synthesize editBarButtonItem;
@synthesize settingsPopover;
@synthesize feedRefreshControl;
@synthesize fetchedResultsController;

- (NSFetchedResultsController *)fetchedResultsController {
    if (!fetchedResultsController) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Feed" inManagedObjectContext:[OCNewsHelper sharedHelper].context];
        [fetchRequest setEntity:entity];
    
        NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"myId" ascending:YES];
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
        [fetchRequest setFetchBatchSize:20];
    
        fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                        managedObjectContext:[OCNewsHelper sharedHelper].context sectionNameKeyPath:nil
                                        cacheName:nil];
        fetchedResultsController.delegate = self;
    }
    return fetchedResultsController;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.clearsSelectionOnViewWillAppear = NO;
    self.tableView.allowsSelection = YES;
    self.tableView.allowsSelectionDuringEditing = YES;

    //self.navigationItem.leftBarButtonItem = self.editButtonItem;
    [self setEditing:NO animated:NO];
    
    currentIndex = -1;
    
    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    fixedSpace.width = 5.0f;
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    NSArray *items = [NSArray arrayWithObjects:
                      flexibleSpace,
                      //self.infoBarButtonItem,
                      //fixedSpace,
                      self.addBarButtonItem,
                      
                      nil];
    
    TransparentToolbar *toolbar = [[TransparentToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 100.0f, 44.0f)];
    toolbar.items = items;
    toolbar.tintColor = self.navigationController.navigationBar.tintColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:toolbar];

    self.refreshControl = self.feedRefreshControl;
    
    self.navigationItem.title = @"Feeds";
    //self.navigationController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    self.navigationController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin;

    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(handleTableviewPress:)];
    //lpgr.minimumPressDuration = 2.0; //seconds
    lpgr.delegate = self;
    [self.tableView addGestureRecognizer:lpgr];
    
    //Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emailSupport:) name:@"EmailSupport" object:nil];

    int status = [[OCAPIClient sharedClient] networkReachabilityStatus];
    NSLog(@"Server status: %i", status);
    
    haveSyncData = YES;
    
    UINavigationController *navController = (UINavigationController*)self.viewDeckController.centerController;
    self.detailViewController = (OCArticleListController *)navController.topViewController;
    
    NSError *error;
    if (![[self fetchedResultsController] performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }

    [self.viewDeckController openLeftView];
    [self willRotateToInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation duration:0];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.fetchedResultsController = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        
        if ((toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight)) {
            CGRect frame = self.navigationController.view.frame;
            frame.size.width = 320;
            self.navigationController.view.frame = frame;
            self.viewDeckController.leftSize = 320;
        } else {
            CGRect frame = self.navigationController.view.frame;
            frame.size.width = 320;
            self.navigationController.view.frame = frame;
            self.viewDeckController.leftSize = 320;
        }
    } else {
        if ((toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) || (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight)) {
            CGRect frame = self.navigationController.view.frame;
            frame.size.width = 300;
            self.navigationController.view.frame = frame;
            self.viewDeckController.leftSize = 300;
            self.viewDeckController.viewDeckController.leftSize = 20;
        } else {
            CGRect frame = self.navigationController.view.frame;
            frame.size.width = 300;
            self.navigationController.view.frame = frame;
            self.viewDeckController.leftSize = 300;
            self.viewDeckController.viewDeckController.leftSize = 0;
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    //return self.feeds.count + 2;
    
    id  sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (void)configureCell:(OCFeedCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    Feed *feed = [self.fetchedResultsController objectAtIndexPath:indexPath];

    BOOL haveIcon = NO;
    NSString *faviconLink = feed.faviconLink;
    //NSLog(@"faviconLink: %@", faviconLink);
    if (![faviconLink isKindOfClass:[NSNull class]]) {
        if ([faviconLink hasPrefix:@"http"]) {
            NSURL *faviconURL = [NSURL URLWithString:faviconLink] ;
            if (faviconURL) {
                if (cell.tag == indexPath.row) {
                    haveIcon = YES;
                    [cell.imageView setImageWithURL:faviconURL placeholderImage:[UIImage imageNamed:@"favicon"]];
                }
            }
        } else {
            [cell.imageView setImage:[UIImage imageNamed:faviconLink]];
        }
    }
    
    cell.countBadge.value = feed.unreadCountValue;

    if (feed.extra) {
        cell.textLabel.text = feed.extra.displayTitle;
    } else {
        cell.textLabel.text = feed.title;
    }

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    OCFeedCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[OCFeedCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    cell.tag = indexPath.row;
    // Configure the cell...
    cell.accessoryView = cell.countBadge;
    [self configureCell:cell atIndexPath:indexPath];
/*
    if (indexPath.row == 0) {
        cell.textLabel.text = @"All Articles";
        [cell.imageView setImage:[UIImage imageNamed:@"favicon"]];
        NSArray *unreadCounts = [self.feeds valueForKey:@"unreadCount"];
        cell.countBadge.value = [[unreadCounts valueForKeyPath:@"@sum.self"] integerValue];
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"Starred";
        [cell.imageView setImage:[UIImage imageNamed:@"star_icon"]];
        NSArray *starredCounts = [self.items valueForKey:@"starred"];
        cell.countBadge.value = [[starredCounts valueForKeyPath:@"@sum.self"] integerValue];
    } else {
        NSDictionary *feed = [self.feeds objectAtIndex:indexPath.row - 2];
        
        BOOL haveIcon = NO;
        NSString *faviconLink = [feed objectForKey:@"faviconLink"];
        //NSLog(@"faviconLink: %@", faviconLink);
        if (![faviconLink isKindOfClass:[NSNull class]]) {
            
            if ([faviconLink hasPrefix:@"http"]) {
                NSURL *faviconURL = [NSURL URLWithString:faviconLink] ;
                if (faviconURL) {
                    if (cell.tag == indexPath.row) {
                        haveIcon = YES;
                        [cell.imageView setImageWithURL:faviconURL placeholderImage:[UIImage imageNamed:@"favicon"]];
                    }
                }
            }
        }
        if (!haveIcon) {
            [cell.imageView setImage:[UIImage imageNamed:@"favicon"]];
        }
*/        
        /*
         if ([[object valueForKey:@"Updating"] boolValue] == YES) {
         cell.accessoryView = cell.activityIndicator;
         [cell.activityIndicator startAnimating];
         } else { */
        ////cell.countBadge.value = [[feed valueForKey:@"unreadCount"] integerValue];
        //[cell.activityIndicator stopAnimating];
        /*    }
         
         if ([[object valueForKey:@"Failure"] boolValue] == YES) {
         cell.detailTextLabel.text = @"Failed to update feed";
         } else {
         cell.detailTextLabel.text = @"";
         }
         */
        ////cell.textLabel.text = [feed valueForKey:@"title"];
        
    ////}
    
    
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    if (indexPath.row < 2) {
        return NO;
    }
    return ([[OCAPIClient sharedClient] networkReachabilityStatus] > 0);
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Feed *feed = [self.fetchedResultsController objectAtIndexPath:indexPath];
        __block NSString *feedId = [feed.myId stringValue];
        
        [[OCAPIClient sharedClient] deletePath:[NSString stringWithFormat:@"feeds/%@", feedId] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            [[OCNewsHelper sharedHelper] deleteFeed:feed];
            NSLog(@"Success");
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"Failure");
            NSString *message = [NSString stringWithFormat:@"The error reported was '%@'", [error localizedDescription]];
            [TSMessage showNotificationInViewController:self.navigationController withTitle:@"Error Deleting Feed" withMessage:message withType:TSMessageNotificationTypeError withDuration:TSMessageNotificationDurationEndless];
        }];        
    }
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
}


// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    //
}


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    currentIndex = indexPath.row;
    if (self.tableView.isEditing) {
        //[self showRenameForIndex:indexPath.row];
    } else {
        Feed *feed = [self.fetchedResultsController objectAtIndexPath:indexPath];
        if (!feed.extra) {
            [[OCNewsHelper sharedHelper] addFeedExtra:feed];
        }
        self.detailViewController.feed = feed;
        [self.viewDeckController closeLeftView];
    }
}

#pragma mark - Actions

- (IBAction)doAdd:(id)sender {
    if ([[OCAPIClient sharedClient] networkReachabilityStatus] > 0) {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Add New Feed" message:@"Enter the url of the feed to add." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Add",nil];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        UITextField * alertTextField = [alert textFieldAtIndex:0];
        alertTextField.keyboardType = UIKeyboardTypeURL;
        alertTextField.placeholder = @"http://example.com/feed";
        [alert show];
    } else {
        [TSMessage showNotificationInViewController:self.navigationController withTitle:@"Unable to Reach Server" withMessage:@"Please check network connection and login." withType:TSMessageNotificationTypeWarning];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
//
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        NSString *newID = [[alertView textFieldAtIndex:0] text];
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:newID, @"url", [NSNumber numberWithInt:0], @"folderId", nil];
        
        [[OCAPIClient sharedClient] postPath:@"feeds" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSLog(@"Feeds: %@", responseObject);
            
            int newFeedId = [[OCNewsHelper sharedHelper] addFeed:responseObject];
            
            [self.tableView reloadData];
            
            NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:200], @"batchSize",
                                    [NSNumber numberWithInt:0], @"offset",
                                    [NSNumber numberWithInt:0], @"type",
                                    [NSNumber numberWithInt:newFeedId], @"id",
                                    [NSNumber numberWithInt:1], @"getRead", nil];
            
            [[OCAPIClient sharedClient] getPath:@"items" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
                //NSLog(@"Updated Items: %@", JSON);
                NSDictionary *jsonDict = (NSDictionary *) responseObject;
                NSArray *newItems = [NSArray arrayWithArray:[jsonDict objectForKey:@"items"]];
                [[OCNewsHelper sharedHelper] updateItems:newItems];
                NSLog(@"Done");

            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSString *message = [NSString stringWithFormat:@"The server repsonded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode], [error localizedDescription]];
                [TSMessage showNotificationInViewController:self.navigationController withTitle:@"Error Retrieving Items" withMessage:message withType:TSMessageNotificationTypeError withDuration:TSMessageNotificationDurationEndless];

            }];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSString *message = [NSString stringWithFormat:@"The server repsonded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode], [error localizedDescription]];
            [TSMessage showNotificationInViewController:self.navigationController withTitle:@"Error Adding Feed" withMessage:message withType:TSMessageNotificationTypeError withDuration:TSMessageNotificationDurationEndless];

        }];
    }
}

- (IBAction)doInfo:(id)sender {
    /*
    CGRect myFrame;
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        myFrame = CGRectMake(0, 0, 1024, 748);
    } else {
        myFrame = CGRectMake(0, 0, 768, 1004);
    }
    AppDelegate* myDelegate = (((AppDelegate*) [UIApplication sharedApplication].delegate));
    FDAboutPanel *aboutPanel = [[FDAboutPanel alloc] initWithFrame:myFrame title:@"About iOCNews"];
    [myDelegate.window.rootViewController.view addSubview:aboutPanel];
	[aboutPanel showFromPoint:CGPointMake(250, 30)];
     */
}

- (IBAction)doEdit:(id)sender {
    //[self setEditing:YES animated:YES];
    UIStoryboard *storyboard;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle:nil];
    } else {
        storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
    }
    [self.viewDeckController presentViewController: [storyboard instantiateViewControllerWithIdentifier:@"login"] animated:YES completion:nil];
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
//    if (editing) {
//        self.navigationItem.leftBarButtonItem = self.editButtonItem;
//    } else {
        UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        fixedSpace.width = 2.0f;
        UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        
        NSArray *items = [NSArray arrayWithObjects:
                          fixedSpace,
                          self.editBarButtonItem,
                          flexibleSpace,
                          nil];
        
        TransparentToolbar *toolbar = [[TransparentToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 100.0f, 44.0f)];
        toolbar.items = items;
        toolbar.tintColor = self.navigationController.navigationBar.tintColor;
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:toolbar];
//    }
}

- (IBAction)doRefresh:(id)sender {
    if ([[OCAPIClient sharedClient] networkReachabilityStatus] > 0) {
        [[OCAPIClient sharedClient] getPath:@"feeds" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSLog(@"Feeds: %@", responseObject);
            
            [[OCNewsHelper sharedHelper] updateFeeds:responseObject];
            [self updateItems];

        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSString *message = [NSString stringWithFormat:@"The server repsonded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode], [error localizedDescription]];
            [TSMessage showNotificationInViewController:self.navigationController withTitle:@"Error Updating Feeds" withMessage:message withType:TSMessageNotificationTypeError withDuration:TSMessageNotificationDurationEndless];
            [self.refreshControl endRefreshing];

        }];
    } else {
        [self.refreshControl endRefreshing];
        [TSMessage showNotificationInViewController:self.navigationController withTitle:@"Unable to Reach Server" withMessage:@"Please check network connection and login." withType:TSMessageNotificationTypeWarning];
    }
    
}

- (void) reloadRow:(NSIndexPath*)indexPath {
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
    if (currentIndex >= 0) {
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:currentIndex inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
    }

}

- (IBAction)handleTableviewPress:(UILongPressGestureRecognizer *)gestureRecognizer; {
    //http://stackoverflow.com/a/14364085/2036378 (why it's a good idea to retrieve the cell)
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        
        CGPoint p = [gestureRecognizer locationInView:self.tableView];
        
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
        if (indexPath == nil) {
            NSLog(@"long press on table view but not on a row");
        } else {
            if ((indexPath.section == 0) && (indexPath.row > 1)) {
                UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                if (cell.isHighlighted) {
                    Feed *feed = [self.fetchedResultsController objectAtIndexPath:indexPath];
                    NSLog(@"Feed title: %@", feed.title);
                    if (!feed.extra) {
                        [[OCNewsHelper sharedHelper] addFeedExtra:feed];
                    }
                    NSLog(@"Feed title: %@", feed.extra.displayTitle);
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle: nil];
                        UINavigationController *navController = [storyboard instantiateViewControllerWithIdentifier: @"feedextra"];
                        OCFeedSettingsController *settingsController = (OCFeedSettingsController*)navController.topViewController;
                        [settingsController loadView];
                        settingsController.feed = feed;
                        settingsController.delegate = self;
                        [self presentViewController:navController animated:YES completion:nil];
                    } else {
                        UINavigationController *navController = (UINavigationController *)self.settingsPopover.contentViewController;
                        OCFeedSettingsController *settingsController = (OCFeedSettingsController *)navController.topViewController;
                        settingsController.feed = feed;
                        settingsController.delegate = self;
                        
                        [self.settingsPopover presentPopoverFromRect:[self.tableView rectForRowAtIndexPath:indexPath] inView:[self view] permittedArrowDirections:UIPopoverArrowDirectionLeft animated:YES];
                    }
                }
            }
        }
    }
}

- (void) feedSettingsUpdate:(OCFeedSettingsController *)settings {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.settingsPopover dismissPopoverAnimated:YES];
    }
    [self.tableView reloadRowsAtIndexPaths:@[[self.fetchedResultsController indexPathForObject:settings.feed]] withRowAnimation:UITableViewRowAnimationAutomatic];
}


#pragma mark - Feeds maintenance

- (void) updateItems {
    if (([[OCAPIClient sharedClient] networkReachabilityStatus] > 0)) {
        if ([[OCNewsHelper sharedHelper] itemCount] > 0) {
            //NSDate *date = [NSDate dateWithTimeIntervalSinceNow:-86400];
            //[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:[date timeIntervalSince1970]] forKey:@"LastModified"];
            NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:[[NSUserDefaults standardUserDefaults] integerForKey:@"LastModified"]], @"lastModified",
                                    [NSNumber numberWithInt:3], @"type",
                                    [NSNumber numberWithInt:0], @"id", nil];
            
            [[OCAPIClient sharedClient] getPath:@"items/updated" parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
                //NSLog(@"Updated Items: %@", JSON);
                NSDictionary *jsonDict = (NSDictionary *) responseObject;
                NSArray *newItems = [NSArray arrayWithArray:[jsonDict objectForKey:@"items"]];
                
                if (newItems.count > 0) {
                    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:[[NSDate date] timeIntervalSince1970]] forKey:@"LastModified"];
                    [[OCNewsHelper sharedHelper] updateItems:newItems];
                }
                
                [self.refreshControl endRefreshing];

            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSString *message = [NSString stringWithFormat:@"The server repsonded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:operation.response.statusCode], [error localizedDescription]];
                [TSMessage showNotificationInViewController:self.navigationController withTitle:@"Error Updating Items" withMessage:message withType:TSMessageNotificationTypeError withDuration:TSMessageNotificationDurationEndless];
            }];
        } else { //first time
            __block NSMutableArray *operations = [NSMutableArray new];
            __block NSMutableArray *addedItems = [NSMutableArray new];
            __block OCAPIClient *client = [OCAPIClient sharedClient];
            [self.fetchedResultsController.fetchedObjects enumerateObjectsUsingBlock:^(Feed *feed, NSUInteger idx, BOOL *stop) {

                NSDictionary *itemParams = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:200], @"batchSize",
                                        [NSNumber numberWithInt:0], @"offset",
                                        [NSNumber numberWithInt:0], @"type",
                                        feed.myId, @"id",
                                        @"true", @"getRead", nil];
                
                NSMutableURLRequest *itemRequest = [client requestWithMethod:@"GET" path:@"items" parameters:itemParams];
                
                AFJSONRequestOperation *itemOperation = [AFJSONRequestOperation JSONRequestOperationWithRequest:itemRequest success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                    
                    //NSLog(@"New Items: %@", JSON);
                    NSDictionary *jsonDict = (NSDictionary *) JSON;
                    NSArray *newItems = [NSArray arrayWithArray:[jsonDict objectForKey:@"items"]];
                    [addedItems addObjectsFromArray:newItems];
                } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                    NSString *message = [NSString stringWithFormat:@"The server repsonded '%@' and the error reported was '%@'", [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], [error localizedDescription]];
                    [TSMessage showNotificationInViewController:self.navigationController withTitle:@"Error Retrieving Items" withMessage:message withType:TSMessageNotificationTypeError withDuration:TSMessageNotificationDurationEndless];
                }];
                BOOL allowInvalid = [[NSUserDefaults standardUserDefaults] boolForKey:@"AllowInvalidSSLCertificate"];
                if (allowInvalid) {
                    [itemOperation setWillSendRequestForAuthenticationChallengeBlock:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
                        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
                            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
                        }
                        
                    }];
                }

                [operations addObject:itemOperation];
            }];
            
            [client enqueueBatchOfHTTPRequestOperations:operations progressBlock:^(NSUInteger numberOfFinishedOperations, NSUInteger totalNumberOfOperations) {
                NSLog(@"Feed %i of %i", numberOfFinishedOperations, totalNumberOfOperations);
            } completionBlock:^(NSArray *operations) {
                [[OCNewsHelper sharedHelper] updateItems:addedItems];
                [self.refreshControl endRefreshing];
            }];
        }
    } else {
        [TSMessage showNotificationInViewController:self.navigationController withTitle:@"Unable to Reach Server" withMessage:@"Please check network connection and login." withType:TSMessageNotificationTypeWarning];
    }
}

- (void) emailSupport:(NSNotification *)n {
    MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
    
    mailViewController.mailComposeDelegate = self;
    [mailViewController setToRecipients:[NSArray arrayWithObject:@"support@peterandlinda.com"]];
    [mailViewController setSubject:@"iOCNews Support Request"];
    [mailViewController setMessageBody:@"<Please state your problem here>\n\n\nI have attached my current subscriptions." isHTML:NO ];
    mailViewController.modalPresentationStyle = UIModalPresentationPageSheet;
    
    [self presentViewController:mailViewController animated:YES completion:nil];
}
#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Toolbar Buttons

- (UIBarButtonItem *)addBarButtonItem {
    
    if (!addBarButtonItem) {
        addBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(doAdd:)];
    }
    
    return addBarButtonItem;
}

- (UIBarButtonItem *)infoBarButtonItem {
    
    if (!infoBarButtonItem) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeInfoDark];
        [button addTarget:self action:@selector(doInfo:) forControlEvents:UIControlEventTouchUpInside];
        infoBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    }
    return infoBarButtonItem;
}

- (UIBarButtonItem *)editBarButtonItem {
    
    if (!editBarButtonItem) {
        editBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear"] style:UIBarButtonItemStylePlain target:self action:@selector(doEdit:)];
        editBarButtonItem.imageInsets = UIEdgeInsetsMake(2.0f, 0.0f, -2.0f, 0.0f);
    }
    return editBarButtonItem;
}
/*
- (UIPopoverController *) settingsPopover {
    if (!settingsPopover) {
        
        FDFeedSettingsController *settingsController = [[FDFeedSettingsController alloc] initWithStyle:UITableViewStyleGrouped];
        UINavigationController *settingsNavController = [[UINavigationController alloc] initWithRootViewController:settingsController];
        settingsNavController.topViewController.navigationItem.title = @"Edit Feed";
        settingsNavController.topViewController.navigationItem.rightBarButtonItem = settingsController.saveBarButtonItem;
        settingsController.delegate = self;
        settingsPopover = [[UIPopoverController alloc] initWithContentViewController:settingsNavController];

    }
    return settingsPopover;
}
*/
- (UIRefreshControl *)feedRefreshControl {
    if (!feedRefreshControl) {
        feedRefreshControl = [[UIRefreshControl alloc] init];
        [feedRefreshControl addTarget:self action:@selector(doRefresh:) forControlEvents:UIControlEventValueChanged];
    }
    
    return feedRefreshControl;
}

- (UIPopoverController *) settingsPopover {
    if (!settingsPopover) {

        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle: nil];
        settingsPopover = [[UIPopoverController alloc] initWithContentViewController:[storyboard instantiateViewControllerWithIdentifier: @"feedextra"]];
        
    }
    return settingsPopover;
}

- (void)popoverViewDidDismiss:(PopoverView *)popoverView {
    _popover = nil;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:(OCFeedCell*)[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray
                                               arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray
                                               arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id )sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller has sent all current change notifications, so tell the table view to process all updates.
    [self.tableView endUpdates];
}

@end

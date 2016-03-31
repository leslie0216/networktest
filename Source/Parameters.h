//
//  Parameters.h
//  NetworkTest
//
//  Created by Chengzhao Li on 2016-03-29.
//  Copyright © 2016 Apportable. All rights reserved.
//

#ifndef Parameters_h
#define Parameters_h

typedef enum networkConnectionType {
    MPC = 0,
    BLUETOOTH = 1,
    WIFI_TCP = 2,
    WIFI_UDP = 3,
    POWER_NONE
} networkConnectionType;

#define SERVER_DID_NOT_START_NOTIFICATION @"NoodlecakeNetworktest_DidNotStartServerNotification"
#define SERVER_DID_FOUND_CLIENT_NOTIFICATION @"NoodlecakeNetworktest_DidFoundClientNotification"
#define SERVER_CLIENT_CONNECTION_DONE_NOTIFICATION @"NoodlecakeNetworktest_DidConnectionDoneNotification"
#define CONNECTION_STATE_CHANGED_NOTIFICATION @"NoodlecakeNetworktest_DidChangeConnectionStateNotification"
#define RECEIVED_DATA_NOTIFICATION @"NoodlecakeNetworktest_DidReceiveDataNotification"

#define TRANSFER_SERVICE_UUID           @"A3EC42C6-ADF8-48A8-8F88-2E32AD32667B"
#define TRANSFER_CHARACTERISTIC_MSG_FROM_PERIPHERAL_UUID    @"481AD972-35A9-44F8-9C9A-9DF1644E1E1E"
#define TRANSFER_CHARACTERISTIC_MSG_FROM_CENTRAL_UUID    @"A147F9FE-0914-4706-9A07-20AAC9D7AB92"

#endif /* Parameters_h */

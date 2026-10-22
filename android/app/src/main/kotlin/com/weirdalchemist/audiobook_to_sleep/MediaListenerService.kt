package com.weirdalchemist.audiobook_to_sleep

import android.service.notification.NotificationListenerService

// Never looks at notifications. Android only lets apps list and control other
// apps' media sessions if they hold notification access, and that access is
// granted to a NotificationListenerService — so this empty one exists for it.
class MediaListenerService : NotificationListenerService()

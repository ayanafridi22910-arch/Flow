package com.example.flow; 

import android.accessibilityservice.AccessibilityService;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import java.util.List;

public class MyAccessibilityService extends AccessibilityService {

    private static final String LOG_TAG = "UrlAccessibilityService";
    private String lastUrl = "";

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        try {
            if (event.getPackageName() != null && event.getPackageName().toString().equals("com.android.chrome")) {
                AccessibilityNodeInfo parentNode = getRootInActiveWindow();
                if (parentNode == null) {
                    return;
                }

                String url = findUrlBar(parentNode);
                // URL agar null nahi hai aur pichle URL se alag hai, tabhi bhejo
                if (url != null && !url.equals(lastUrl)) {
                    lastUrl = url;
                    Log.d(LOG_TAG, "Chrome URL Visited: " + url);
                    // Native code se Flutter (MainActivity.kt) ko data bhejo
                    MainActivity.Companion.sendUrlToFlutter(url);
                }
            }
        } catch (Exception e) {
            Log.e(LOG_TAG, "Error in onAccessibilityEvent: " + e.getMessage());
        }
    }

    private String findUrlBar(AccessibilityNodeInfo nodeInfo) {
        if (nodeInfo == null) return null;

        List<AccessibilityNodeInfo> urlBarNodes = nodeInfo.findAccessibilityNodeInfosByViewId("com.android.chrome:id/url_bar");
        if (urlBarNodes != null && !urlBarNodes.isEmpty()) {
            AccessibilityNodeInfo urlNode = urlBarNodes.get(0);
            if (urlNode != null && urlNode.getText() != null) {
                return urlNode.getText().toString();
            }
        }
        return null;
    }

    @Override
    public void onInterrupt() {
        Log.e(LOG_TAG, "Accessibility service interrupted.");
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        Log.d(LOG_TAG, "URL Tracking Accessibility Service Connected!");
    }
}
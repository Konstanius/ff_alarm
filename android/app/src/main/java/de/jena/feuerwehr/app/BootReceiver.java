package de.jena.feuerwehr.app;

import android.content.BroadcastReceiver;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;

import androidx.core.content.ContextCompat;

public class BootReceiver extends BroadcastReceiver {
    @SuppressLint("WakelockTimeout")
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (action.equalsIgnoreCase(Intent.ACTION_BOOT_COMPLETED) || action.equalsIgnoreCase(Intent.ACTION_LOCKED_BOOT_COMPLETED) || action.equalsIgnoreCase("android.intent.action.QUICKBOOT_POWERON") || action.equalsIgnoreCase("com.htc.intent.action.QUICKBOOT_POWERON")) {
            ContextCompat.startForegroundService(context, new Intent(context, de.jena.feuerwehr.app.GeofenceService.class));
        }
    }
}

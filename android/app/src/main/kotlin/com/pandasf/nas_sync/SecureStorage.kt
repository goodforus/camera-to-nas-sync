package com.pandasf.nas_sync

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.GeneralSecurityException

/**
 * Android Keystore-backed secure storage.
 *
 * Passwords are encrypted with an AES-GCM key stored in the Android Keystore
 * and the ciphertext is persisted in EncryptedSharedPreferences. The key never
 * leaves the Keystore.
 *
 * Method channel: com.pandasf.nas_sync/secure_storage
 *   write  { key, value } -> Boolean
 *   read   { key }        -> String?
 *   delete { key }        -> Boolean
 *   containsKey { key }   -> Boolean
 */
class SecureStorage private constructor(context: Context) {
    private val prefs: SharedPreferences
    private val channel: MethodChannel? = null

    companion object {
        private const val PREFS_NAME = "nas_sync_secure_prefs"
        private const val MASTER_KEY_ALIAS = "nas_sync_master_key"
        private const val CHANNEL = "com.pandasf.nas_sync/secure_storage"

        @Volatile private var instance: SecureStorage? = null

        @JvmStatic
        fun getInstance(context: Context): SecureStorage {
            return instance ?: synchronized(this) {
                instance ?: SecureStorage(context).also { instance = it }
            }
        }
    }

    init {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        prefs = EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun write(key: String, value: String): Boolean {
        return try {
            prefs.edit().putString(key, value).apply()
            true
        } catch (e: Exception) {
            false
        }
    }

    fun read(key: String): String? {
        return try {
            prefs.getString(key, null)
        } catch (e: Exception) {
            null
        }
    }

    fun delete(key: String): Boolean {
        return try {
            prefs.edit().remove(key).apply()
            true
        } catch (e: Exception) {
            false
        }
    }

    fun containsKey(key: String): Boolean {
        return prefs.contains(key)
    }

    // Expose prefs for testing/diagnostics
    internal fun getPrefs(): SharedPreferences = prefs
}

/**
 * Registers the MethodChannel with a FlutterEngine. The SecureStorage instance
 * is bound on first call using the supplied context.
 */
object SecureStorageChannelHandler {
    private const val CHANNEL = "com.pandasf.nas_sync/secure_storage"
    private var storage: SecureStorage? = null

    fun register(messenger: io.flutter.plugin.common.BinaryMessenger,
                 context: android.content.Context) {
        storage = SecureStorage.getInstance(context)
        val channel = MethodChannel(messenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "write" -> {
                    val key = call.argument<String>("key") ?: ""
                    val value = call.argument<String>("value") ?: ""
                    result.success(storage?.write(key, value) ?: false)
                }
                "read" -> {
                    val key = call.argument<String>("key") ?: ""
                    result.success(storage?.read(key))
                }
                "delete" -> {
                    val key = call.argument<String>("key") ?: ""
                    result.success(storage?.delete(key) ?: false)
                }
                "containsKey" -> {
                    val key = call.argument<String>("key") ?: ""
                    result.success(storage?.containsKey(key) ?: false)
                }
                else -> result.notImplemented()
            }
        }
    }
}

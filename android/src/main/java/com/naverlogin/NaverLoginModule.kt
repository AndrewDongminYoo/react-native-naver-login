package com.naverlogin

import android.os.Handler
import android.os.Looper
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableNativeMap
import com.navercorp.nid.NaverIdLoginSDK
import com.navercorp.nid.oauth.OAuthLoginCallback
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

class NaverLoginModule(
  reactContext: ReactApplicationContext,
) : NativeNaverLoginSpec(reactContext) {
  companion object {
    const val NAME = NativeNaverLoginSpec.NAME
  }

  private val mainHandler = Handler(Looper.getMainLooper())
  private val loginInProgress = AtomicBoolean(false)

  // -------------------------------------------------------------------------
  // initialize
  // -------------------------------------------------------------------------

  override fun initialize(params: ReadableMap) {
    val clientId = params.getString("consumerKey") ?: ""
    val clientSecret = params.getString("consumerSecret") ?: ""
    val clientName = params.getString("appName") ?: ""
    NaverIdLoginSDK.initialize(reactApplicationContext, clientId, clientSecret, clientName)
  }

  // -------------------------------------------------------------------------
  // login
  // -------------------------------------------------------------------------

  override fun login(promise: Promise) {
    if (!loginInProgress.compareAndSet(false, true)) {
      val failureResponse =
        WritableNativeMap().apply {
          putString("message", "A login request is already in progress.")
          putBoolean("isCancel", false)
          putString("lastErrorCodeFromNaverSDK", "")
          putString("lastErrorDescriptionFromNaverSDK", "")
        }
      promise.resolve(
        WritableNativeMap().apply {
          putBoolean("isSuccess", false)
          putMap("failureResponse", failureResponse)
        },
      )
      return
    }

    val activity =
      currentActivity ?: run {
        loginInProgress.set(false)
        val failureResponse =
          WritableNativeMap().apply {
            putString("message", "NaverLogin.login() called with no current Activity.")
            putBoolean("isCancel", false)
            putString("lastErrorCodeFromNaverSDK", "")
            putString("lastErrorDescriptionFromNaverSDK", "")
          }
        promise.resolve(
          WritableNativeMap().apply {
            putBoolean("isSuccess", false)
            putMap("failureResponse", failureResponse)
          },
        )
        return
      }

    val callback =
      object : OAuthLoginCallback {
        override fun onSuccess() {
          loginInProgress.set(false)
          val successResponse =
            WritableNativeMap().apply {
              putString("accessToken", NaverIdLoginSDK.getAccessToken() ?: "")
              putString("refreshToken", NaverIdLoginSDK.getRefreshToken() ?: "")
              putString("expiresAtUnixSecondString", NaverIdLoginSDK.getExpiresAt().toString())
              putString("tokenType", NaverIdLoginSDK.getTokenType() ?: "Bearer")
            }
          val result =
            WritableNativeMap().apply {
              putBoolean("isSuccess", true)
              putMap("successResponse", successResponse)
            }
          promise.resolve(result)
        }

        override fun onFailure(
          httpStatus: Int,
          message: String,
        ) {
          loginInProgress.set(false)
          val failureResponse =
            WritableNativeMap().apply {
              putString("message", message)
              putBoolean("isCancel", false)
              putString("lastErrorCodeFromNaverSDK", NaverIdLoginSDK.getLastErrorCode().code)
              putString("lastErrorDescriptionFromNaverSDK", NaverIdLoginSDK.getLastErrorDescription() ?: "")
            }
          val result =
            WritableNativeMap().apply {
              putBoolean("isSuccess", false)
              putMap("failureResponse", failureResponse)
            }
          promise.resolve(result)
        }

        override fun onError(
          errorCode: Int,
          message: String,
        ) {
          loginInProgress.set(false)
          // errorCode -1 is user cancellation in the Naver SDK.
          val isCancel = errorCode == -1
          val failureResponse =
            WritableNativeMap().apply {
              putString("message", message)
              putBoolean("isCancel", isCancel)
              putString("lastErrorCodeFromNaverSDK", NaverIdLoginSDK.getLastErrorCode().code)
              putString("lastErrorDescriptionFromNaverSDK", NaverIdLoginSDK.getLastErrorDescription() ?: "")
            }
          val result =
            WritableNativeMap().apply {
              putBoolean("isSuccess", false)
              putMap("failureResponse", failureResponse)
            }
          promise.resolve(result)
        }
      }

    mainHandler.post {
      NaverIdLoginSDK.authenticate(activity, callback)
    }
  }

  // -------------------------------------------------------------------------
  // logout
  // -------------------------------------------------------------------------

  override fun logout(promise: Promise) {
    NaverIdLoginSDK.logout()
    promise.resolve(null)
  }

  // -------------------------------------------------------------------------
  // deleteToken
  // -------------------------------------------------------------------------

  override fun deleteToken(promise: Promise) {
    val callback =
      object : OAuthLoginCallback {
        override fun onSuccess() {
          NaverIdLoginSDK.logout()
          promise.resolve(null)
        }

        override fun onFailure(
          httpStatus: Int,
          message: String,
        ) {
          promise.reject("DELETE_TOKEN_FAILED", message)
        }

        override fun onError(
          errorCode: Int,
          message: String,
        ) {
          promise.reject("DELETE_TOKEN_ERROR", message)
        }
      }
    // Revoke server-side first; clear local state (logout) only after server confirms.
    NaverIdLoginSDK.callDeleteTokenApi(reactApplicationContext, callback)
  }

  // -------------------------------------------------------------------------
  // getProfile
  // -------------------------------------------------------------------------

  override fun getProfile(
    accessToken: String,
    promise: Promise,
  ) {
    Thread {
      val connection =
        (URL("https://openapi.naver.com/v1/nid/me").openConnection() as HttpURLConnection).also {
          it.requestMethod = "GET"
          it.setRequestProperty("Authorization", "Bearer $accessToken")
          it.connectTimeout = 10_000
          it.readTimeout = 10_000
        }
      try {
        val responseCode = connection.responseCode
        if (responseCode != 200) {
          promise.reject("PROFILE_HTTP_ERROR", "HTTP $responseCode")
          return@Thread
        }

        val body = BufferedReader(InputStreamReader(connection.inputStream)).readText()
        val json = JSONObject(body)
        promise.resolve(jsonObjectToWritableMap(json))
      } catch (e: Exception) {
        promise.reject("PROFILE_ERROR", e.message ?: "Unknown error", e)
      } finally {
        connection.disconnect()
      }
    }.start()
  }

  // -------------------------------------------------------------------------
  // JSON helper
  // -------------------------------------------------------------------------

  private fun jsonObjectToWritableMap(json: JSONObject): WritableNativeMap {
    val map = WritableNativeMap()
    json.keys().forEach { key ->
      when (val value = json.opt(key)) {
        is JSONObject -> map.putMap(key, jsonObjectToWritableMap(value))
        is String -> map.putString(key, value)
        is Int -> map.putInt(key, value)
        is Long -> map.putDouble(key, value.toDouble())
        is Double -> map.putDouble(key, value)
        is Boolean -> map.putBoolean(key, value)
        JSONObject.NULL, null -> map.putNull(key)
        else -> map.putString(key, value.toString())
      }
    }
    return map
  }
}

package com.naverlogin

import com.facebook.react.bridge.ReactApplicationContext

class NaverLoginModule(reactContext: ReactApplicationContext) :
  NativeNaverLoginSpec(reactContext) {

  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }

  companion object {
    const val NAME = NativeNaverLoginSpec.NAME
  }
}

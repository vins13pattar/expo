// Copyright 2004-present Facebook. All Rights Reserved.

#pragma once

#include <algorithm>
#include <functional>
#include <stdexcept>

#include <ABI21_0_0jschelpers/ABI21_0_0JavaScriptCore.h>
#include <ABI21_0_0jschelpers/ABI21_0_0Value.h>

#ifndef RN_EXPORT
#define RN_EXPORT __attribute__((visibility("default")))
#endif

namespace facebook {
namespace ReactABI21_0_0 {

class RN_EXPORT JSException : public std::exception {
public:
  explicit JSException(const char* msg)
    : msg_(msg) {}

  explicit JSException(JSContextRef ctx, JSValueRef exn, const char* msg) {
    buildMessage(ctx, exn, nullptr, msg);
  }

  explicit JSException(JSContextRef ctx, JSValueRef exn, JSStringRef sourceURL) {
    buildMessage(ctx, exn, sourceURL, nullptr);
  }

  const std::string& getStack() const {
    return stack_;
  }

  virtual const char* what() const noexcept override {
    return msg_.c_str();
  }

private:
  std::string msg_;
  std::string stack_;

  void buildMessage(JSContextRef ctx, JSValueRef exn, JSStringRef sourceURL, const char* errorMsg);
};

namespace ExceptionHandling {
  struct ExtractedEror {
    std::string message;
    // Stacktrace formatted like JS stack
    // method@filename[:line[:column]]
    std::string stack;
  };
  using PlatformErrorExtractor = std::function<ExtractedEror(const std::exception &ex, const char *context)>;
  extern PlatformErrorExtractor platformErrorExtractor;
}

using JSFunction = std::function<JSValueRef(JSContextRef, JSObjectRef, size_t, const JSValueRef[])>;

JSObjectRef makeFunction(
    JSContextRef ctx,
    const char* name,
    JSFunction function);

RN_EXPORT void installGlobalFunction(
    JSGlobalContextRef ctx,
    const char* name,
    JSFunction function);

JSObjectRef makeFunction(
    JSGlobalContextRef ctx,
    const char* name,
    JSObjectCallAsFunctionCallback callback);

RN_EXPORT void installGlobalFunction(
    JSGlobalContextRef ctx,
    const char* name,
    JSObjectCallAsFunctionCallback callback);

void installGlobalProxy(
    JSGlobalContextRef ctx,
    const char* name,
    JSObjectGetPropertyCallback callback);

void removeGlobal(JSGlobalContextRef ctx, const char* name);

JSValueRef evaluateScript(
    JSContextRef ctx,
    JSStringRef script,
    JSStringRef sourceURL);

#if WITH_FBJSCEXTENSIONS
JSValueRef evaluateSourceCode(
    JSContextRef ctx,
    JSSourceCodeRef source,
    JSStringRef sourceURL);
#endif

JSValueRef translatePendingCppExceptionToJSError(JSContextRef ctx, const char *exceptionLocation);
JSValueRef translatePendingCppExceptionToJSError(JSContextRef ctx, JSObjectRef jsFunctionCause);

template<JSValueRef (method)(JSContextRef ctx,
        JSObjectRef function,
        JSObjectRef thisObject,
        size_t argumentCount,
        const JSValueRef arguments[],
        JSValueRef *exception)>
inline JSObjectCallAsFunctionCallback exceptionWrapMethod() {
  struct funcWrapper {
    static JSValueRef call(
        JSContextRef ctx,
        JSObjectRef function,
        JSObjectRef thisObject,
        size_t argumentCount,
        const JSValueRef arguments[],
        JSValueRef *exception) {
      try {
        return (*method)(ctx, function, thisObject, argumentCount, arguments, exception);
      } catch (...) {
        *exception = translatePendingCppExceptionToJSError(ctx, function);
        return JSC_JSValueMakeUndefined(ctx);
      }
    }
  };

  return &funcWrapper::call;
}

} }

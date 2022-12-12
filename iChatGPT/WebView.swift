//
//  Webview.swift
//  test
//
//  Created by oblank on 7/28/20.
//  taken from https://gist.github.com/prafullakumar/937c5d908e44f0497862c2beb835d7b3
//

import SwiftUI
import WebKit

class WebViewStateModel: ObservableObject {
    @Published var pageTitle: String? = nil
    @Published var loading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var goBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var goForward: Bool = false
    @Published var currUrl: URL? = nil
    @Published var webview: WKWebView? = nil
}

struct WebView: View {
    enum NavigationAction {
        case decidePolicy(WKNavigationAction,  (WKNavigationActionPolicy) -> Void) //mendetory
        case didRecieveAuthChallange(URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) //mendetory
        case didStartProvisionalNavigation(WKNavigation)
        case didReceiveServerRedirectForProvisionalNavigation(WKNavigation)
        case didCommit(WKNavigation)
        case didFinish(WKNavigation)
        case didFailProvisionalNavigation(WKNavigation,Error)
        case didFail(WKNavigation,Error)
    }
    
    private var actionDelegate: ((_ navigationAction: WebView.NavigationAction) -> Void)?
    
    @ObservedObject var webViewStateModel: WebViewStateModel
    let uRLRequest: URLRequest?
    let htmlString: String?
    let localUrl: URL?
    let injectObject: [String : Any]?
    let javascriptCallHandler: WKScriptMessageHandler?
    
    var body: some View {
        WebViewWrapper(
            webViewStateModel: webViewStateModel,
            action: actionDelegate,
            request: uRLRequest,
            htmlString: htmlString,
            localUrl: localUrl,
            injectObject: injectObject,
            javascriptCallHandler: javascriptCallHandler
        )
    }
    
    /*
     if passed onNavigationAction it is mendetory to complete URLAuthenticationChallenge and decidePolicyFor callbacks
     */
    init(uRLRequest: URLRequest?, htmlString: String?, localUrl: URL?, injectObject: [String : Any]?, webViewStateModel: WebViewStateModel?, onNavigationAction: ((_ navigationAction: WebView.NavigationAction) -> Void)?, javascriptCallHandler: WKScriptMessageHandler? = nil) {
        self.uRLRequest = uRLRequest
        self.htmlString = htmlString
        self.localUrl = localUrl
        self.injectObject = injectObject
        self.webViewStateModel = webViewStateModel ?? WebViewStateModel()
        self.actionDelegate = onNavigationAction
        self.javascriptCallHandler = javascriptCallHandler
    }
    
    init(url: URL, injectObject: [String : Any]? = nil, webViewStateModel: WebViewStateModel? = nil, onNavigationAction: ((_ navigationAction: WebView.NavigationAction) -> Void)? = nil) {
        self.init(
            uRLRequest: URLRequest(url: url),
            htmlString: nil,
            localUrl: nil,
            injectObject: injectObject,
            webViewStateModel: webViewStateModel,
            onNavigationAction: onNavigationAction
        )
    }
    
    init(localUrl: URL, injectObject: [String : Any]? = nil, webViewStateModel: WebViewStateModel? = nil, onNavigationAction: ((_ navigationAction: WebView.NavigationAction) -> Void)? = nil, javascriptCallHandler: WKScriptMessageHandler? = nil) {
        self.init(
            uRLRequest: nil,
            htmlString: nil,
            localUrl: localUrl,
            injectObject: injectObject,
            webViewStateModel: webViewStateModel,
            onNavigationAction: onNavigationAction,
            javascriptCallHandler: javascriptCallHandler
        )
    }
    
    init(htmlString: String, injectObject: [String : Any]? = nil, webViewStateModel: WebViewStateModel? = nil, onNavigationAction: ((_ navigationAction: WebView.NavigationAction) -> Void)? = nil, javascriptCallHandler: WKScriptMessageHandler? = nil) {
        self.init(
            uRLRequest: nil,
            htmlString: htmlString,
            localUrl: nil,
            injectObject: injectObject,
            webViewStateModel: webViewStateModel,
            onNavigationAction: onNavigationAction,
            javascriptCallHandler: javascriptCallHandler
        )
    }
}

//class MessageHandler: NSObject, WKScriptMessageHandler {
//   func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
//       print("JS发送到IOS的数据====\(message.body), name=\(message.name)")
//   }
//}

struct WebViewWrapper : UIViewRepresentable {
    
    @ObservedObject var webViewStateModel: WebViewStateModel
    let action: ((_ navigationAction: WebView.NavigationAction) -> Void)?
    let request: URLRequest?
    let htmlString: String?
    let localUrl: URL?
    let injectObject: [String : Any]?
    let javascriptCallHandler: WKScriptMessageHandler?
    
    init(
        webViewStateModel: WebViewStateModel,
        action: ((_ navigationAction: WebView.NavigationAction) -> Void)?,
        request: URLRequest?,
        htmlString: String?,
        localUrl: URL?,
        injectObject: [String : Any]? = [:],
        javascriptCallHandler: WKScriptMessageHandler?
    ) {
        self.action = action
        self.request = request
        self.htmlString = htmlString
        self.localUrl = localUrl
        self.injectObject = injectObject
        self.webViewStateModel = webViewStateModel
        self.javascriptCallHandler = javascriptCallHandler
    }
    
    func makeUIView(context: Context) -> WKWebView  {
        // inject custom objects
        let userContent = WKUserContentController.init()
        
        // 提前塞入全局变量
        let jsonData = try? JSONSerialization.data(withJSONObject: injectObject ?? [:], options: .prettyPrinted)
        let jsonText = String.init(data: jsonData!, encoding: String.Encoding.utf8)
        let script = WKUserScript.init(source: "window.injectObj = \(jsonText!)", injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContent.addUserScript(script)
        
//        // 加载完后执行
//        let js = "document.getElementById('test').innerText = 'ios原生调用js方法改变h5页面样式'"
//        let script2 = WKUserScript.init(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
//        userContent.addUserScript(script2)
        
        // 配置
        let config = WKWebViewConfiguration.init()
        config.userContentController = userContent
        
        // js调navtive的情况
        // JAVASCRIPT_CALL_NATIVE 是JavaScript向IOS发送数据时，使用的函数名
        if javascriptCallHandler != nil {
            config.userContentController.add(javascriptCallHandler!, name: "JAVASCRIPT_CALL_NATIVE")
        }

        let view: WKWebView = WKWebView.init(frame: UIScreen.main.bounds, configuration: config)
        view.navigationDelegate = context.coordinator
        if htmlString != nil {
            view.loadHTMLString(htmlString!, baseURL: nil)
        } else if request != nil {
            view.load(request!)
        } else if localUrl != nil {
            view.loadFileURL(localUrl!, allowingReadAccessTo: localUrl!.deletingLastPathComponent())
        } else {
            view.loadHTMLString("", baseURL: nil)
        }
        
        // 圆角
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
 
        return view
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.canGoBack, webViewStateModel.goBack {
            uiView.goBack()
            webViewStateModel.goBack = false
        }
        
        if uiView.canGoForward, webViewStateModel.goForward {
            uiView.goForward()
            webViewStateModel.goForward = false
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(action: action, webViewStateModel: webViewStateModel)
    }
    
    final class Coordinator: NSObject {
        @ObservedObject var webViewStateModel: WebViewStateModel
        
        let action: ((_ navigationAction: WebView.NavigationAction) -> Void)?
        
        init(action: ((_ navigationAction: WebView.NavigationAction) -> Void)?, webViewStateModel: WebViewStateModel) {
            self.action = action
            self.webViewStateModel = webViewStateModel
        }
        
    }
}

extension WebViewWrapper.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action == nil {
            decisionHandler(.allow)
        } else {
            action?(.decidePolicy(navigationAction, decisionHandler))
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        webViewStateModel.loading = true
        webViewStateModel.canGoBack = webView.canGoBack
        webViewStateModel.canGoForward = webView.canGoForward
        webViewStateModel.currUrl = webView.url
        webViewStateModel.pageTitle = webView.title
        action?(.didStartProvisionalNavigation(navigation))
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        webViewStateModel.canGoBack = webView.canGoBack
        webViewStateModel.canGoForward = webView.canGoForward
        webViewStateModel.currUrl = webView.url
        webViewStateModel.pageTitle = webView.title
        action?(.didReceiveServerRedirectForProvisionalNavigation(navigation))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webViewStateModel.loading = false
        webViewStateModel.canGoBack = webView.canGoBack
        webViewStateModel.canGoForward = webView.canGoForward
        webViewStateModel.currUrl = webView.url
        webViewStateModel.pageTitle = webView.title
        action?(.didFailProvisionalNavigation(navigation, error))
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        //        webViewStateModel.loading = false
        webViewStateModel.canGoBack = webView.canGoBack
        webViewStateModel.canGoForward = webView.canGoForward
        webViewStateModel.currUrl = webView.url
        webViewStateModel.pageTitle = webView.title
        action?(.didCommit(navigation))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webViewStateModel.loading = false
        webViewStateModel.canGoBack = webView.canGoBack
        webViewStateModel.canGoForward = webView.canGoForward
        webViewStateModel.currUrl = webView.url
        webViewStateModel.pageTitle = webView.title
        action?(.didFinish(navigation))
        
        // 持有引用，用于外部调用
        webViewStateModel.webview = webView
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webViewStateModel.loading = false
        webViewStateModel.canGoBack = webView.canGoBack
        webViewStateModel.canGoForward = webView.canGoForward
        webViewStateModel.currUrl = webView.url
        webViewStateModel.pageTitle = webView.title
        action?(.didFail(navigation, error))
        
        // 持有引用，用于外部调用
        webViewStateModel.webview = webView
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if action == nil  {
            completionHandler(.performDefaultHandling, nil)
        } else {
            action?(.didRecieveAuthChallange(challenge, completionHandler))
        }
    }
    
}


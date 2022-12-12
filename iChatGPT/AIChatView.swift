//
//  AIChatView.swift
//  iChatGPT
//
//  Created by HTC on 2022/12/8.
//  Copyright © 2022 37 Mobile Games. All rights reserved.
//

import SwiftUI
import MarkdownText
import WebKit
import SwiftyJSON

struct SiteCookies {
    var UA: String
    var cookiesString: String
    var cookies: [String: HTTPCookie]
}

var openAiCookies: SiteCookies? = nil


struct AIChatView: View {
    
    @State private var isAddPresented: Bool = false
    @State private var searchText = ""
    @StateObject private var chatModel = AIChatModel(contents: [])
    @ObservedObject public var webViewStateModel: WebViewStateModel = WebViewStateModel()
    
    // 接受js的请求并打开相应页面
    private class TagsJavaScriptCallHandler: NSObject, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            print("JS发送到IOS的数据====\(message.body), name=\(message.name)")
            let jsonString = "\(message.body)"
            if let dataFromString = jsonString.data(using: .utf8, allowLossyConversion: true) {
                if let json = try? JSON(data: dataFromString) {
                    print(json)
                    //showTagLogsList(type: .tag, tagStr: "\(json["params"]["tag"].stringValue)", count: Int32(json["params"]["count"].intValue))
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                WebView(
                    url: URL(string: "https://chat.openai.com/chat")!,
                    webViewStateModel: webViewStateModel
                )
                .frame(height: isAddPresented ? UIScreen.main.bounds.height - 40 : 0)
                .onChange(of: webViewStateModel.webview?.configuration.websiteDataStore.httpCookieStore) { _ in
                    webViewStateModel.webview?.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                        var cookieStr = ""
                        var cookieItems: [String: HTTPCookie] = [:]
                        for cookie in cookies {
                            print(cookie.name, cookie.value, cookie.domain)
                            cookieStr += "\(cookie.name)=\(cookie.value); "
                            cookieItems[cookie.name] = cookie
                        }
                        openAiCookies = SiteCookies(UA: WKWebView().value(forKey: "userAgent") as! String, cookiesString: cookieStr, cookies: cookieItems)
                    }
                }
                
                
                List {
                    ForEach(chatModel.contents, id: \.datetime) { item in
                        Section(header: Text(item.datetime)) {
                            VStack(alignment: .leading) {
                                HStack(alignment: .top) {
                                    AvatarImageView(url: item.userAvatarUrl)
                                    MarkdownText(item.issue)
                                        .padding(.top, 3)
                                }
                                Divider()
                                HStack(alignment: .top) {
                                    AvatarImageView(url: item.botAvatarUrl)
                                    if item.isResponse {
                                        // Text(.init(item.answer))
                                        MarkdownText(item.answer ?? "")
                                    } else {
                                        ProgressView()
                                        Text("请求中..")
                                            .padding(.leading, 10)
                                    }
                                }
                                .padding([.top, .bottom], 3)
                            }.contextMenu {
                                ChatContextMenu(searchText: $searchText, chatModel: chatModel, item: item)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                Spacer()
                ChatInputView(searchText: $searchText, chatModel: chatModel)
                    .padding([.leading, .trailing], 12)
            }
            .markdownHeadingStyle(.custom)
            .markdownQuoteStyle(.custom)
            .markdownCodeStyle(.custom)
            .markdownInlineCodeStyle(.custom)
            .markdownOrderedListBulletStyle(.custom)
            .markdownUnorderedListBulletStyle(.custom)
            .markdownImageStyle(.custom)
            .navigationTitle("OpenAI ChatGPT")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                HStack {
                    addButton
            })
//            .sheet(isPresented: $isAddPresented, content: {
//                TokenSettingView(isAddPresented: $isAddPresented, chatModel: chatModel)
//            })
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image("chatgpt").resizable()
                            .frame(width: 25, height: 25)
                        Text("ChatGPT").font(.headline)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private var addButton: some View {
        Button(action: {
            isAddPresented.toggle()
        }) {
            HStack {
                if isAddPresented {
                    Text("完成")
                        .fontWeight(.semibold)
                } else {
                    if #available(iOS 15.4, *) {
                        Image(systemName: "key.viewfinder").imageScale(.large)
                    } else {
                        Image(systemName: "key.icloud").imageScale(.large)
                    }
                }
            }.frame(height: 40)
        }
    }
}

struct AvatarImageView: View {
    let url: String
    
    var body: some View {
        Group {
            ImageLoaderView(urlString: url) {
                Color(.tertiarySystemGroupedBackground)
            } image: { image in
                image.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
            }
        }
        .cornerRadius(5)
        .frame(width: 25, height: 25)
        .padding(.trailing, 10)
    }
}

struct AIChatView_Previews: PreviewProvider {
    static var previews: some View {
        AIChatView()
    }
}

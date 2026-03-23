import SwiftUI

private let accent = Color(red: 0.35, green: 0.80, blue: 0.52)
private let bg     = Color(red: 0.10, green: 0.13, blue: 0.10)

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        // Avatar + name
                        VStack(spacing: 10) {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(LinearGradient(colors:[Color(red:0.30,green:0.55,blue:0.40),
                                                                  Color(red:0.18,green:0.38,blue:0.28)],
                                                          startPoint:.topLeading, endPoint:.bottomTrailing))
                                    .frame(width: 96, height: 96)
                                    .overlay(Text("🦆").font(.system(size: 52)))

                                Circle()
                                    .fill(bg)
                                    .frame(width: 30, height: 30)
                                    .overlay(Image(systemName:"qrcode")
                                        .font(.system(size:13))
                                        .foregroundColor(Color(white:0.65)))
                                    .offset(x: -4, y: 4)
                            }
                            VStack(spacing: 2) {
                                Text("Иван").font(.system(size:26,weight:.bold)).foregroundColor(.white)
                                Text("@lendic42").font(.system(size:15)).foregroundColor(Color(white:0.5))
                            }
                        }
                        .padding(.top, 20).padding(.bottom, 18)

                        // Change photo
                        card {
                            row(icon:"camera", color:accent, title:"Изменить фотографию", chevron:false)
                        }
                        .padding(.horizontal,16).padding(.bottom,14)

                        // Accounts
                        card {
                            HStack(spacing:12) {
                                Circle().fill(Color(red:0.50,green:0.20,blue:0.20)).frame(width:36,height:36)
                                    .overlay(Text("🐺").font(.system(size:20)))
                                Text("Lendic").font(.system(size:16,weight:.medium)).foregroundColor(.white)
                                Spacer()
                                Text("214").font(.system(size:12,weight:.bold)).foregroundColor(.white)
                                    .padding(.horizontal,7).padding(.vertical,3)
                                    .background(Capsule().fill(accent))
                            }
                            .padding(.horizontal,16).padding(.vertical,12)

                            Divider().background(Color(white:0.18)).padding(.leading,62)

                            HStack(spacing:12) {
                                Circle().strokeBorder(accent,lineWidth:2).frame(width:36,height:36)
                                    .overlay(Image(systemName:"plus").font(.system(size:16,weight:.semibold)).foregroundColor(accent))
                                Text("Добавить аккаунт").font(.system(size:16)).foregroundColor(accent)
                                Spacer()
                            }
                            .padding(.horizontal,16).padding(.vertical,12)
                        }
                        .padding(.horizontal,16).padding(.bottom,8)

                        // Main settings
                        card {
                            row(icon:"person.fill",  color:Color(red:0.85,green:0.22,blue:0.22), title:"Мой профиль")
                            sep; row(icon:"sparkles",     color:Color(red:0.52,green:0.52,blue:0.62), title:"Whitegram")
                            sep; row(icon:"arrow.triangle.2.circlepath", color:Color(red:0.22,green:0.72,blue:0.40), title:"Прокси", value:"Отключён")
                            sep; row(icon:"creditcard.fill", color:Color(red:0.18,green:0.42,blue:0.85), title:"Кошелёк")
                        }
                        .padding(.horizontal,16).padding(.bottom,8)

                        // More settings
                        card {
                            row(icon:"bell.fill",     color:Color(red:0.90,green:0.48,blue:0.14), title:"Уведомления")
                            sep; row(icon:"lock.fill",     color:Color(red:0.38,green:0.58,blue:0.90), title:"Конфиденциальность")
                            sep; row(icon:"paintbrush.fill", color:Color(red:0.58,green:0.32,blue:0.90), title:"Оформление")
                            sep; row(icon:"folder.fill",  color:Color(red:0.48,green:0.68,blue:0.32), title:"Папки с чатами")
                            sep; row(icon:"network",       color:Color(red:0.32,green:0.62,blue:0.85), title:"Использование данных")
                        }
                        .padding(.horizontal,16).padding(.bottom,30)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button("Изм.") {}.foregroundColor(accent)
                }
            }
            .toolbarBackground(bg, for:.navigationBar)
            .toolbarBackground(.visible, for:.navigationBar)
        }
    }

    @ViewBuilder
    func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing:0) { content() }
            .background(RoundedRectangle(cornerRadius:14).fill(Color(white:0.12)))
    }

    @ViewBuilder
    func row(icon: String, color: Color, title: String, value: String? = nil, chevron: Bool = true) -> some View {
        HStack(spacing:14) {
            RoundedRectangle(cornerRadius:8).fill(color).frame(width:32,height:32)
                .overlay(Image(systemName:icon).font(.system(size:16,weight:.semibold)).foregroundColor(.white))
            Text(title).font(.system(size:16)).foregroundColor(.white)
            Spacer()
            if let v = value { Text(v).font(.system(size:15)).foregroundColor(Color(white:0.42)) }
            if chevron { Image(systemName:"chevron.right").font(.system(size:13,weight:.semibold)).foregroundColor(Color(white:0.32)) }
        }
        .padding(.horizontal,16).padding(.vertical,13)
    }

    var sep: some View {
        Divider().background(Color(white:0.18)).padding(.leading,56)
    }
}

# frozen_string_literal: true

puts "=== Seeding database ==="

# -----------------------------------------------
# 1. Prefectures (47)
# -----------------------------------------------
PREFECTURES = [
  { name: "北海道", slug: "hokkaido" },
  { name: "青森県", slug: "aomori" },
  { name: "岩手県", slug: "iwate" },
  { name: "宮城県", slug: "miyagi" },
  { name: "秋田県", slug: "akita" },
  { name: "山形県", slug: "yamagata" },
  { name: "福島県", slug: "fukushima" },
  { name: "茨城県", slug: "ibaraki" },
  { name: "栃木県", slug: "tochigi" },
  { name: "群馬県", slug: "gunma" },
  { name: "埼玉県", slug: "saitama" },
  { name: "千葉県", slug: "chiba" },
  { name: "東京都", slug: "tokyo" },
  { name: "神奈川県", slug: "kanagawa" },
  { name: "新潟県", slug: "niigata" },
  { name: "富山県", slug: "toyama" },
  { name: "石川県", slug: "ishikawa" },
  { name: "福井県", slug: "fukui" },
  { name: "山梨県", slug: "yamanashi" },
  { name: "長野県", slug: "nagano" },
  { name: "岐阜県", slug: "gifu" },
  { name: "静岡県", slug: "shizuoka" },
  { name: "愛知県", slug: "aichi" },
  { name: "三重県", slug: "mie" },
  { name: "滋賀県", slug: "shiga" },
  { name: "京都府", slug: "kyoto" },
  { name: "大阪府", slug: "osaka" },
  { name: "兵庫県", slug: "hyogo" },
  { name: "奈良県", slug: "nara" },
  { name: "和歌山県", slug: "wakayama" },
  { name: "鳥取県", slug: "tottori" },
  { name: "島根県", slug: "shimane" },
  { name: "岡山県", slug: "okayama" },
  { name: "広島県", slug: "hiroshima" },
  { name: "山口県", slug: "yamaguchi" },
  { name: "徳島県", slug: "tokushima" },
  { name: "香川県", slug: "kagawa" },
  { name: "愛媛県", slug: "ehime" },
  { name: "高知県", slug: "kochi" },
  { name: "福岡県", slug: "fukuoka" },
  { name: "佐賀県", slug: "saga" },
  { name: "長崎県", slug: "nagasaki" },
  { name: "熊本県", slug: "kumamoto" },
  { name: "大分県", slug: "oita" },
  { name: "宮崎県", slug: "miyazaki" },
  { name: "鹿児島県", slug: "kagoshima" },
  { name: "沖縄県", slug: "okinawa" }
].freeze

PREFECTURES.each do |pref|
  Prefecture.find_or_create_by!(slug: pref[:slug]) do |p|
    p.name = pref[:name]
  end
end
puts "  Prefectures: #{Prefecture.count}"

# -----------------------------------------------
# 2. Shops (~15)
# -----------------------------------------------
tokyo     = Prefecture.find_by!(slug: "tokyo")
osaka     = Prefecture.find_by!(slug: "osaka")
kanagawa  = Prefecture.find_by!(slug: "kanagawa")
aichi     = Prefecture.find_by!(slug: "aichi")
fukuoka   = Prefecture.find_by!(slug: "fukuoka")
hokkaido  = Prefecture.find_by!(slug: "hokkaido")
miyagi    = Prefecture.find_by!(slug: "miyagi")
saitama   = Prefecture.find_by!(slug: "saitama")
chiba     = Prefecture.find_by!(slug: "chiba")
hyogo     = Prefecture.find_by!(slug: "hyogo")

SHOPS = [
  { prefecture: tokyo,    name: "マルハン新宿東宝ビル店",   slug: "maruhan-shinjuku",       address: "東京都新宿区歌舞伎町1-19-1",      lat: 35.6942100, lng: 139.7013400 },
  { prefecture: tokyo,    name: "メガガイア新宿店",         slug: "mega-gaia-shinjuku",     address: "東京都新宿区歌舞伎町1-22-1",      lat: 35.6944500, lng: 139.7020300 },
  { prefecture: tokyo,    name: "エスパス日拓新宿歌舞伎町店", slug: "espas-shinjuku",         address: "東京都新宿区歌舞伎町1-21-1",      lat: 35.6946200, lng: 139.7018500 },
  { prefecture: tokyo,    name: "ビックマーチ上野店",       slug: "big-march-ueno",         address: "東京都台東区上野6-9-1",           lat: 35.7101700, lng: 139.7747200 },
  { prefecture: osaka,    name: "マルハン梅田店",           slug: "maruhan-umeda",          address: "大阪府大阪市北区小松原町3-3",      lat: 34.7024800, lng: 135.5010200 },
  { prefecture: osaka,    name: "キコーナなんば店",         slug: "kicona-namba",           address: "大阪府大阪市中央区難波1-5-20",     lat: 34.6682300, lng: 135.5010600 },
  { prefecture: kanagawa, name: "マルハン横浜町田店",       slug: "maruhan-yokohama-machida", address: "神奈川県横浜市瀬谷区目黒町30-1", lat: 35.4596000, lng: 139.4977000 },
  { prefecture: kanagawa, name: "ガーデン横浜店",           slug: "garden-yokohama",        address: "神奈川県横浜市西区南幸2-1-22",     lat: 35.4657900, lng: 139.6201100 },
  { prefecture: aichi,    name: "キング観光名古屋錦店",     slug: "king-nagoya-nishiki",    address: "愛知県名古屋市中区錦3-15-5",       lat: 35.1700800, lng: 136.9066500 },
  { prefecture: aichi,    name: "マルハン名古屋駅前店",     slug: "maruhan-nagoya-ekimae",  address: "愛知県名古屋市中村区椿町15-22",     lat: 35.1706000, lng: 136.8817000 },
  { prefecture: fukuoka,  name: "マルハン博多駅前店",       slug: "maruhan-hakata-ekimae",  address: "福岡県福岡市博多区博多駅前2-2-1",   lat: 33.5897000, lng: 130.4207000 },
  { prefecture: hokkaido, name: "イーグルR-1札幌店",        slug: "eagle-r1-sapporo",       address: "北海道札幌市中央区南3条西2丁目",    lat: 43.0570000, lng: 141.3540000 },
  { prefecture: miyagi,   name: "マルハン仙台駅前店",       slug: "maruhan-sendai-ekimae",  address: "宮城県仙台市青葉区中央1-7-18",     lat: 38.2600000, lng: 140.8820000 },
  { prefecture: saitama,  name: "ガーデン大宮店",           slug: "garden-omiya",           address: "埼玉県さいたま市大宮区桜木町1-1-1", lat: 35.9062000, lng: 139.6238000 },
  { prefecture: hyogo,    name: "マルハン三宮店",           slug: "maruhan-sannomiya",      address: "兵庫県神戸市中央区三宮町1-9-1",    lat: 34.6910000, lng: 135.1930000 }
].freeze

SHOPS.each do |shop_data|
  Shop.find_or_create_by!(slug: shop_data[:slug]) do |s|
    s.prefecture = shop_data[:prefecture]
    s.name       = shop_data[:name]
    s.address    = shop_data[:address]
    s.lat        = shop_data[:lat]
    s.lng        = shop_data[:lng]
  end
end
puts "  Shops: #{Shop.count}"

# -----------------------------------------------
# 3. Machine Models (~30)
# -----------------------------------------------
MACHINES = [
  # スマスロ (AT機)
  { name: "スマスロ北斗の拳",               maker: "サミー",         machine_type: :slot, spec_type: :type_at,       slug: "smart-hokuto",            released_on: "2023-04-03" },
  { name: "バジリスク絆2 天膳BLACK EDITION", maker: "ミズホ",         machine_type: :slot, spec_type: :type_at,       slug: "basilisk-kizuna2-tenzen", released_on: "2024-04-08" },
  { name: "押忍!番長ZERO",                  maker: "大都技研",       machine_type: :slot, spec_type: :type_at,       slug: "banchou-zero",            released_on: "2022-07-04" },
  { name: "甲鉄城のカバネリ",               maker: "サミー",         machine_type: :slot, spec_type: :type_at,       slug: "kabaneri",                released_on: "2022-12-05" },
  { name: "Lバキ 強くなりたくば喰らえ!!!",   maker: "フィールズ",     machine_type: :slot, spec_type: :type_at,       slug: "baki",                    released_on: "2024-01-09" },
  { name: "沖ドキ!GOLD",                    maker: "ユニバーサル",   machine_type: :slot, spec_type: :type_at,       slug: "okidoki-gold",            released_on: "2024-07-01" },
  { name: "モンキーターンV",                 maker: "山佐",           machine_type: :slot, spec_type: :type_at,       slug: "monkey-turn-v",           released_on: "2024-02-05" },
  { name: "ヴァルヴレイヴ",                  maker: "三共",           machine_type: :slot, spec_type: :type_at,       slug: "valvrave",                released_on: "2023-10-02" },
  { name: "リゼロ鬼がかりver.",              maker: "大都技研",       machine_type: :slot, spec_type: :type_at,       slug: "rezero-onigakari",        released_on: "2024-06-03" },
  { name: "からくりサーカス",                maker: "サミー",         machine_type: :slot, spec_type: :type_at,       slug: "karakuri-circus",         released_on: "2023-07-03" },
  { name: "炎炎ノ消防隊",                   maker: "サンスリー",     machine_type: :slot, spec_type: :type_at,       slug: "enen-shouboutai",         released_on: "2024-03-04" },
  { name: "マクロスフロンティア4",            maker: "三共",           machine_type: :slot, spec_type: :type_at,       slug: "macross-frontier-4",      released_on: "2024-05-07" },
  { name: "交響詩篇エウレカセブン",           maker: "サミー",         machine_type: :slot, spec_type: :type_at,       slug: "eureka-seven",            released_on: "2024-08-05" },
  { name: "ガンダムユニコーン",              maker: "サンキョー",     machine_type: :slot, spec_type: :type_at,       slug: "gundam-unicorn",          released_on: "2023-12-04" },
  { name: "とある魔術の禁書目録",            maker: "サミー",         machine_type: :slot, spec_type: :type_at,       slug: "toaru-index",             released_on: "2024-09-02" },
  { name: "コードギアス 反逆のルルーシュ3",   maker: "サミー",         machine_type: :slot, spec_type: :type_at,       slug: "code-geass-3",            released_on: "2023-11-06" },
  { name: "転生したらスライムだった件",       maker: "サミー",         machine_type: :slot, spec_type: :type_at,       slug: "tensura",                 released_on: "2024-10-07" },
  { name: "ソードアート・オンライン",         maker: "サミー",         machine_type: :slot, spec_type: :type_at,       slug: "sao",                     released_on: "2024-04-01" },
  # ART機
  { name: "押忍!サラリーマン番長2",          maker: "大都技研",       machine_type: :slot, spec_type: :type_art,      slug: "salaryman-banchou-2",     released_on: "2023-08-07" },
  { name: "アナターのオット!?はーです",       maker: "ミズホ",         machine_type: :slot, spec_type: :type_art,      slug: "anata-otto-hearts",       released_on: "2024-11-04" },
  # A+AT機
  { name: "ハナハナホウオウ -天翔-",          maker: "パイオニア",     machine_type: :slot, spec_type: :type_a_plus_at, slug: "hanahana-houou-tenshou",  released_on: "2023-06-05" },
  { name: "クランキークレスト",              maker: "ユニバーサル",   machine_type: :slot, spec_type: :type_a_plus_at, slug: "cranky-crest",            released_on: "2024-12-02" },
  # A タイプ (ノーマル)
  { name: "マイジャグラーV",                 maker: "北電子",         machine_type: :slot, spec_type: :type_a,        slug: "my-juggler-v",            released_on: "2022-12-05" },
  { name: "アイムジャグラーEX-TP",           maker: "北電子",         machine_type: :slot, spec_type: :type_a,        slug: "aim-juggler-ex-tp",       released_on: "2023-09-04" },
  { name: "ファンキージャグラー2",            maker: "北電子",         machine_type: :slot, spec_type: :type_a,        slug: "funky-juggler-2",         released_on: "2023-03-06" },
  { name: "ゴーゴージャグラー3",              maker: "北電子",         machine_type: :slot, spec_type: :type_a,        slug: "gogo-juggler-3",          released_on: "2024-02-05" },
  { name: "ハッピージャグラーVIII",           maker: "北電子",         machine_type: :slot, spec_type: :type_a,        slug: "happy-juggler-viii",      released_on: "2024-08-05" },
  # パチスロ
  { name: "P牙狼 GOLD IMPACT",              maker: "サンセイR&D",    machine_type: :pachislot, spec_type: :type_at,  slug: "garo-gold-impact",        released_on: "2023-05-08" },
  { name: "Pフィーバー機動戦士ガンダムSEED", maker: "サンキョー",     machine_type: :pachislot, spec_type: :type_at,  slug: "gundam-seed",             released_on: "2024-01-09" },
  { name: "P大工の源さん超韋駄天2",          maker: "三洋",           machine_type: :pachislot, spec_type: :type_at,  slug: "daiku-gensun-idaten2",    released_on: "2024-06-03" },
].freeze

MACHINES.each do |m|
  MachineModel.find_or_create_by!(slug: m[:slug]) do |mm|
    mm.name         = m[:name]
    mm.maker        = m[:maker]
    mm.machine_type = m[:machine_type]
    mm.spec_type    = m[:spec_type]
    mm.released_on  = m[:released_on]
  end
end
puts "  MachineModels: #{MachineModel.count}"

# -----------------------------------------------
# 4. Admin User
# -----------------------------------------------
User.find_or_create_by!(email: "admin@example.com") do |u|
  u.password     = "password"
  u.nickname     = "admin"
  u.role         = :admin
  u.trust_score  = 1.0
end
puts "  Admin user created (admin@example.com / password)"

puts "=== Seeding complete ==="

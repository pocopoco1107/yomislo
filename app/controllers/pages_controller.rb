class PagesController < ApplicationController
  def privacy
    set_meta_tags title: "プライバシーポリシー",
                  description: "ヨミスロのプライバシーポリシー。Cookie の利用や個人情報の取り扱いについて。"
  end

  def terms
    set_meta_tags title: "利用規約",
                  description: "ヨミスロの利用規約。ご利用にあたってのルールと禁止事項。"
  end

  def tokushou
    set_meta_tags title: "特定商取引法に基づく表記",
                  description: "ヨミスロの特定商取引法に基づく表記。"
  end

  def about
    set_meta_tags title: "ヨミスロについて",
                  description: "ヨミスロは、パチスロのリセット・設定情報を打ち手同士で共有し、自分の収支も記録できるサイトです。"
  end
end

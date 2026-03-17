class AddWebhookCredentialsToWhatsappAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :whatsapp_accounts, :webhook_verify_token, :string
    add_column :whatsapp_accounts, :app_secret_ciphertext, :text

    add_index :whatsapp_accounts,
      :webhook_verify_token,
      unique: true,
      where: "webhook_verify_token IS NOT NULL",
      name: "index_whatsapp_accounts_on_webhook_verify_token_unique"
  end
end

defmodule Snitch.Demo.PaymentMethod do

    alias Snitch.Core.Tools.MultiTenancy.Repo
    alias Snitch.Data.Schema.PaymentMethod

    def create_payment_methods do
        
        Repo.delete_all(PaymentMethod)
        create_payment_method!("card-payments", "ccd", PayuBiz)
        create_payment_method!("COD", "cod", CashOnDelivery)
        create_payment_method!("Stripe", "str", Stripe)
    end

    def create_payment_method!(name, code, provider) do
        params = %{
          name: name,
          code: code,
          provider: provider
        }
        %PaymentMethod{} |> PaymentMethod.create_changeset(params) |> Repo.insert!
    end

end

defmodule Snitch.Data.Schema.Product do
  @moduledoc """
  Models a Product.
  """

  use Snitch.Data.Schema
  use Rummage.Ecto
  alias Snitch.Data.Schema.Product.NameSlug

  alias Snitch.Data.Schema.{
    Variation,
    Image,
    ProductOptionValue,
    VariationTheme,
    Review,
    ProductBrand,
    StockItem,
    ShippingCategory,
    Taxon
  }

  alias Money.Ecto.Composite.Type, as: MoneyType

  @type t :: %__MODULE__{}

  schema "snitch_products" do
    field(:name, :string, null: false, default: "")
    field(:description, :string)
    field(:available_on, :utc_datetime)
    field(:deleted_at, :utc_datetime)
    field(:discontinue_on, :utc_datetime)
    field(:slug, :string)
    field(:meta_description, :string)
    field(:meta_keywords, :string)
    field(:meta_title, :string)
    field(:promotionable, :boolean)
    field(:selling_price, MoneyType)
    field(:max_retail_price, MoneyType)
    field(:height, :decimal, default: Decimal.new(0))
    field(:width, :decimal, default: Decimal.new(0))
    field(:depth, :decimal, default: Decimal.new(0))
    field(:sku, :string)
    field(:position, :integer)
    field(:weight, :decimal, default: Decimal.new(0))
    field(:is_active, :boolean, default: true)
    field(:state, :string, default: "draft")
    timestamps()

    has_many(:variations, Variation, foreign_key: :parent_product_id, on_replace: :delete)
    has_many(:variants, through: [:variations, :child_product])

    many_to_many(
      :products,
      Snitch.Data.Schema.Product,
      join_through: "snitch_product_variants",
      join_keys: [parent_product_id: :id, child_product_id: :id]
    )

    has_many(:options, ProductOptionValue)
    has_many(:stock_items, StockItem)

    many_to_many(:reviews, Review, join_through: "snitch_product_reviews")
    many_to_many(:images, Image, join_through: "snitch_product_images", on_replace: :delete)

    belongs_to(:theme, VariationTheme)
    belongs_to(:brand, ProductBrand)
    belongs_to(:shipping_category, ShippingCategory)
    belongs_to(:taxon, Taxon)
  end

  @required_fields ~w(name selling_price max_retail_price taxon_id shipping_category_id)a
  @optional_fields ~w(description meta_description meta_keywords meta_title brand_id height width depth weight state)a

  def create_changeset(model, params \\ %{}) do
    common_changeset(model, params)
  end

  def update_changeset(model, params \\ %{}) do
    model
    |> common_changeset(params)
    |> cast_assoc(:images, with: &Image.changeset/2)
  end

  def associate_image_changeset(product, images) do
    product = Repo.preload(product, [:images])

    product
    |> change
    |> put_assoc(:images, images)
  end

  def variant_create_changeset(parent_product, params) do
    parent_product
    |> Repo.preload([:variants, :options])
    |> cast(params, [:theme_id])
    |> validate_required([:theme_id])
    |> cast_assoc(:variations, required: true)
    |> theme_change_check()
  end

  def delete_changeset(product, _params \\ %{}) do
    product = Repo.preload(product, [:products])

    variant_params =
      product.products
      |> Enum.map(&%{"is_active" => false, "id" => &1.id})

    params = %{"id" => product.id, "is_active" => false, "products" => variant_params}

    product
    |> cast(params, [:is_active])
    |> cast_assoc(:products, with: &cast(&1, &2, [:is_active]))
  end

  def child_product(model, params \\ %{}) do
    model
    |> common_changeset(params)
    |> cast_assoc(:options)
  end

  defp common_changeset(model, params) do
    model
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_amount(:selling_price)
    |> NameSlug.maybe_generate_slug()
    |> NameSlug.unique_constraint()
  end

  defp theme_change_check(changeset) do
    case get_change(changeset, :theme_id) do
      nil -> handle_variant_replace(changeset)
      _ -> changeset
    end
  end

  def handle_variant_replace(changeset) do
    variant_changes =
      get_change(changeset, :variations)
      |> Enum.map(fn c ->
        if c.action == :replace do
          Map.update(c, :action, nil, fn x -> nil end)
        else
          c
        end
      end)

    put_change(changeset, :variations, variant_changes)
  end
end

defmodule Snitch.Data.Schema.Product.NameSlug do
  @moduledoc false

  use EctoAutoslugField.Slug, from: :name, to: :slug
end

# Creates the table the Next app's callback verification reads.
#
# It lives here, in a Rails migration, because Rails owns this schema — the
# Next app deliberately runs no migration step (see cloudbuild-next.yml), so a
# table that exists only as a Prisma model exists nowhere at all. That was not
# theoretical: the model was added without this migration, and the failure is
# silent in the worst way. The token lookup raises, the SDK reads a raising
# store as an auth failure, and the callback route answers a neutral 200
# because Fluid blocks a live checkout on this response. Every genuine callback
# refused, no error rate moves, nothing alerts.
#
# The shape is dictated by the SDK's own model and must stay identical across
# the fleet — see prisma/schema.prisma, FluidCallbackRegistration.
#
# Only the digest is stored. Fluid presents the plaintext token on every
# request, so a digest is enough to find the registration, and a database dump
# then yields no working callback credentials.
class CreateFluidCallbackRegistrations < ActiveRecord::Migration[8.0]
  def change
    # `id: false` with a string primary key: the SDK keys these rows by Fluid's
    # registration uuid, not by a local autoincrement. A bigint `id` here would
    # not match what Prisma declares as `@id`.
    create_table :fluid_callback_registrations, id: false do |t|
      t.string :uuid, null: false, primary_key: true
      t.string :dri, null: false
      t.string :definition_name, null: false
      t.string :token_digest, null: false
      t.string :url, null: false

      t.timestamps
    end

    # Unique because the digest is how an inbound callback finds its
    # registration. Two rows sharing one digest would make that lookup
    # ambiguous, and the SDK would have no basis for choosing a tenant.
    add_index :fluid_callback_registrations, :token_digest, unique: true
    # Not unique: one installation legitimately holds several registrations,
    # one per callback definition.
    add_index :fluid_callback_registrations, :dri
  end
end

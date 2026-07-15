module PlantSightingsHelper
  def plant_sighting_status_badge(sighting)
    content_tag(:span, I18n.t(sighting.status, scope: 'plant_sightings.status'),
                class: "sighting-status-badge status-#{sighting.status}")
  end
end

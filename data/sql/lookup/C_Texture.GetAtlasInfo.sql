SELECT
  a.AtlasHeight,
  a.AtlasWidth,
  a.FileDataID,
  m.CommittedBottom,
  m.CommittedFlags,
  m.CommittedLeft,
  m.CommittedRight,
  m.CommittedTop,
  m.OverrideHeight,
  m.OverrideWidth
FROM
  UiTextureAtlasMember m
  JOIN UiTextureAtlas a ON a.ID = m.UiTextureAtlasID
  LEFT JOIN UiTextureAtlasElement e ON e.ID = m.UiTextureAtlasElementID
WHERE
  lower(m.CommittedName) = lower(?1)
  OR lower(e.Name) = lower(?1)
LIMIT 1;

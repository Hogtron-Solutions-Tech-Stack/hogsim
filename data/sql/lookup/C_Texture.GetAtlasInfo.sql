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
WHERE
  m.CommittedName = ?1 COLLATE NOCASE
UNION ALL
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
  UiTextureAtlasElement e
  JOIN UiTextureAtlasMember m ON m.UiTextureAtlasElementID = e.ID
  JOIN UiTextureAtlas a ON a.ID = m.UiTextureAtlasID
WHERE
  e.Name = ?1 COLLATE NOCASE
LIMIT 1;

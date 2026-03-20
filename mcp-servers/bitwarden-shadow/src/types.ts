export interface BitwardenShadowConfig {
  session: string;
  shadowCollectionId: string;
  adminCollectionId?: string;
}
export interface BitwardenCollection {
  id: string;
  organizationId: string;
  name: string;
  externalId: string | null;
  readOnly?: boolean;
}
export interface BitwardenItem {
  id: string;
  organizationId: string | null;
  folderId: string | null;
  type: number;
  name: string;
  notes: string | null;
  collectionIds: string[];
  favorite: boolean;
  reprompt: number;
  revisionDate: string;
  creationDate: string;
  deletedDate: string | null;
  login?: { username: string | null; password: string | null; totp: string | null };
  fields?: Array<{ name: string; value: string; type: number }>;
}
export interface ShadowEntry {
  itemId: string;
  itemName: string;
  itemType: string;
  collectionIds: string[];
}

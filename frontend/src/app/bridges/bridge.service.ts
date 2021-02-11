import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { addTokenQueryString, toWebsocketUrl } from 'app/utils';
import { Observable, Observer } from 'rxjs';
import { SessionService } from '../session.service';
import { BridgeIndexData, BridgeMetadata, BridgeResource, BridgeResourceEntry, BridgeResourceMap, BridgeSignal, FullOwnerId, BridgeTokenInfo, FullBridgeTokenInfo } from './bridge';
import { EnvironmentService } from 'app/environment.service';

export type BridgeInfoUpdate = { count: number };

@Injectable()
export class BridgeService {
    constructor(
        private http: HttpClient,
        private sessionService: SessionService,
        private environmentService: EnvironmentService,
    ) {
        this.http = http;
        this.sessionService = sessionService;
    }

    private async getBridgeIndexUrl(): Promise<string> {
        const userId = (await this.sessionService.getSession()).user_id;
        return `${this.environmentService.getApiRoot()}/users/id/${userId}/bridges`;
    }


    private getGroupBridgeIndexUrl(groupId: string): string {
        return `${this.environmentService.getApiRoot()}/groups/by-id/${groupId}/bridges`;
    }

    private getSpecificBridgeUrl(bridgeId: string): string {
        return `${this.environmentService.getApiRoot()}/bridges/by-id/${bridgeId}`;
    }

    private getBridgeHistoricUrl(bridgeId: string): string {
        return `${this.environmentService.getApiRoot()}/bridges/by-id/${bridgeId}/signals/history`;
    }

    private getBridgeSignalsUrl(bridgeId: string): string {
        const url = `${this.environmentService.getApiRoot()}/bridges/by-id/${bridgeId}/signals`;
        return toWebsocketUrl(this.environmentService, url);
    }

    private getBridgeResourcesUrl(bridgeId: string): string {
        return `${this.environmentService.getApiRoot()}/bridges/by-id/${bridgeId}/resources`;
    }

    private getBridgeTokensUrl(bridgeId: string): string {
        return `${this.environmentService.getApiRoot()}/bridges/by-id/${bridgeId}/tokens`;
    }

    private getBridgeTokenByNameUrl(bridgeId: string, tokenName: string): string {
        return `${this.environmentService.getApiRoot()}/bridges/by-id/${bridgeId}/tokens/by-name/${tokenName}`;
    }

    private updateConnectionResourceUrl(connectionId: string, resourceName: string): string {
        return `${this.environmentService.getApiRoot()}/connections/by-id/${connectionId}/resources/by-name/${resourceName}`;
    }

    public getConnectionUrl(bridgeId: string): string {
        return toWebsocketUrl(this.environmentService,
                              `${this.environmentService.getApiRoot()}/bridges/by-id/${bridgeId}/communication`);
    }

    async createServicePort(name: string): Promise<BridgeMetadata> {
        const url = await this.getBridgeIndexUrl();

        const response = (await this.http.post(url, JSON.stringify({ name: name }),
                                               { headers: this.sessionService.addJsonContentType(
                                                   this.sessionService.getAuthHeader())
                                               }).toPromise());

        return response as BridgeMetadata;
    }

    async listUserBridges(): Promise<{bridges: BridgeIndexData[]}> {
        const url = await this.getBridgeIndexUrl();
        const response = (await this.http.get(url,
                                              { headers: this.sessionService.getAuthHeader()})
            .toPromise());

        const bridgeData = response as BridgeIndexData[];

        return {
            bridges: bridgeData,
        };
    }

    async createGroupBridge(name: string, groupId: string): Promise<BridgeMetadata> {
        const url = this.getGroupBridgeIndexUrl(groupId);

        const response = (await this.http.post(url, JSON.stringify({ name: name }),
                                               { headers: this.sessionService.addJsonContentType(
                                                   this.sessionService.getAuthHeader())
                                               }).toPromise());

        return response as BridgeMetadata;
    }

    async listGroupBridges(groupId: string): Promise<BridgeIndexData[]> {
        const url = this.getGroupBridgeIndexUrl(groupId);
        const response = (await this.http.get(url,
                                              { headers: this.sessionService.getAuthHeader()})
                          .toPromise());

        return response as BridgeIndexData[];
    }

    async deleteBridge(bridgeId: string): Promise<boolean> {
        const url = await this.getSpecificBridgeUrl(bridgeId);
        const response = (await this.http.delete(url,
                                                 { headers: this.sessionService.getAuthHeader() })
                          .toPromise());

        return (response as { success: boolean }).success;
    }

    async setShares(connectionId: string, resourceName: string, shares: {[key: string]: {name: string, shared_with: FullOwnerId[]}}, options?: { asGroup?: string; }) {
        let url = this.updateConnectionResourceUrl(connectionId, resourceName);
        if (options && options.asGroup) {
            url += '?as_group=' + options.asGroup;
        }

        const response = (await this.http.patch(url, { shared: shares },
                                                { headers: this.sessionService.addJsonContentType(
                                                    this.sessionService.getAuthHeader())
                                                }).toPromise());
    }

    async getBridgeResources(bridgeId: string, asGroup?: string): Promise<BridgeResource[]> {
        let url = this.getBridgeResourcesUrl(bridgeId);
        if (asGroup) {
            url += '?as_group=' + asGroup;
        }

        const response = (await this.http.get(url,
                                              { headers: this.sessionService.getAuthHeader() })
            .toPromise()) as BridgeResourceMap;

        const resources: BridgeResource[] = [];

        for (const resource of Object.keys(response)) {
            const values: BridgeResourceEntry[] = [];

            for (const valId of Object.keys(response[resource])) {
                const value = response[resource][valId];
                values.push({ id: valId, name: value.name, connection_id: value.connection_id, shared_with: value.shared_with })
            }

            resources.push({ name: resource, values: values });
        }

        return resources;
    }

    public async getBridgeTokens(bridgeId: string, asGroup?: string): Promise<BridgeTokenInfo[]> {
        let url = this.getBridgeTokensUrl(bridgeId);
        if (asGroup) {
            url += '?as_group=' + asGroup;
        }

        const response = (await this.http.get(url,
                                              { headers: this.sessionService.getAuthHeader() })
            .toPromise());

        return ((response as any)['tokens'] as BridgeTokenInfo[]) || [];
    }

    public async createBridgeToken(bridgeId: string, tokenName: string, asGroup: string): Promise<FullBridgeTokenInfo> {
        let url = this.getBridgeTokensUrl(bridgeId);
        if (asGroup) {
            url += '?as_group=' + asGroup;
        }

        const response = (await this.http.post(url, { name: tokenName.trim() },
                          { headers: this.sessionService.addJsonContentType(
                              this.sessionService.getAuthHeader())
                          }).toPromise());

        return response as FullBridgeTokenInfo;
    }

    public async getBridgeHistoric(bridgeId: string, asGroup?: string): Promise<any[]> {
        let url = this.getBridgeHistoricUrl(bridgeId);
        if (asGroup) {
            url += '?as_group=' + asGroup;
        }

        const response = (await this.http.get(url,{ headers: this.sessionService.getAuthHeader()}
                                              ).toPromise());

        return (response as any)['data'];
    }

    public async revokeToken(bridgeId: string, tokenName: string, asGroup?: string): Promise<void> {
        let url = this.getBridgeTokenByNameUrl(bridgeId, tokenName);
        if (asGroup) {
            url += '?as_group=' + asGroup;
        }

        const response = (await this.http.delete(url,
                                                 { headers: this.sessionService.addJsonContentType(
                                                     this.sessionService.getAuthHeader())
                                                 }).toPromise());

    }


    getBridgeSignals(bridgeId: string, asGroup?: string): Observable<BridgeSignal> {
        const token = this.sessionService.getToken();

        let url = addTokenQueryString(this.getBridgeSignalsUrl(bridgeId), token);
        if (asGroup) {
            url += '&as_group=' + asGroup;
        }

        let manuallyClosed = false;

        return new Observable<BridgeSignal>((observer) => {
            const websocket = new WebSocket(url);
            websocket.onopen = (() => {
                console.log("Connected");
            });

            websocket.onmessage = ((ev) => {
                if (typeof(ev.data) === "string" ){
                    observer.next(JSON.parse(ev.data));
                }
                else {
                    const reader = new FileReader();

                    // This fires after the blob has been read/loaded.
                    reader.addEventListener('loadend', (e) => {
                        const text = (e.srcElement as any).result;
                        observer.next(JSON.parse(text));
                    });

                    reader.readAsText(ev.data);
                }
            });

            websocket.onclose = (() => {
                if (!manuallyClosed) {
                    console.error("Complete");
                }
                observer.complete();
            });

            websocket.onerror = ((ev) => {
                if (!manuallyClosed) {
                    console.error("Error");
                }
                observer.error(ev);
            });

            // Unsubscription procedure
            return () => {
                manuallyClosed = true;
                websocket.close();
            };
        });
    }
}

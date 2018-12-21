import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import 'rxjs/add/operator/map';
import 'rxjs/add/operator/toPromise';
import * as API from './api-config';
import { ContentType } from './content-type';
import { MonitorMetadata } from './monitor';
import { SessionService } from './session.service';

@Injectable()
export class MonitorService {
    constructor(
        private http: HttpClient,
        private sessionService: SessionService,
    ) {
        this.http = http;
        this.sessionService = sessionService;
    }

    public async getListMonitorsUrl() {
        const userApiRoot = await this.sessionService.getUserApiRoot();
        return userApiRoot + '/monitors/';
    }

    public async getRetrieveMonitorUrl(_user_id: string, Monitor_id: string) {
      const userApiRoot = await this.sessionService.getUserApiRoot();
      return userApiRoot + '/monitors/' + Monitor_id;
    }

    public async getUpdateMonitorUrl(MonitorUserName: string, Monitor_id: string) {
      const userApiRoot = await this.sessionService.getApiRootForUser(MonitorUserName);
      return userApiRoot + '/monitors/' + Monitor_id;
    }

    public getMonitors(): Promise<MonitorMetadata[]> {
        return this.getListMonitorsUrl().then((url) =>
          this.http.get(url, {headers: this.sessionService.getAuthHeader()})
                  .map((response) => {
                      return response as MonitorMetadata[]
                  })
                  .toPromise());
    }
}
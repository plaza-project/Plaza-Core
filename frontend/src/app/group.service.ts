import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Collaborator, CollaboratorRole } from 'app/types/collaborator';
import { ContentType } from './content-type';
import { GroupInfo, UserGroupInfo } from './group';
import { SessionService } from './session.service';
import { SharedResource } from './bridges/bridge';
import { EnvironmentService } from './environment.service';
import { ground } from './utils';

export interface UserAutocompleteInfo {
    id: string,
    username: string,
};

@Injectable()
export class GroupService {
    constructor(
        private http: HttpClient,
        private sessionService: SessionService,
        private environmentService: EnvironmentService,
    ) {
        this.http = http;
        this.sessionService = sessionService;
    }

    getUserAutocompleteUrl(): string {
        return `${this.environmentService.getApiRoot()}/utils/autocomplete/users`;
    }

    getCreateGroupUrl(): string {
        return `${this.environmentService.getApiRoot()}/groups`;
    }

    getGroupInfoUrl(groupName: string): string {
        return `${this.environmentService.getApiRoot()}/groups/by-name/${groupName}`;
    }

    getGroupCollaboratorsUrl(groupId: string): string {
        return `${this.environmentService.getApiRoot()}/groups/by-id/${groupId}/collaborators`;
    }

    updateGroupCollaboratorsUrl(groupId: string): string {
        return `${this.environmentService.getApiRoot()}/groups/by-id/${groupId}/collaborators`;
    }

    getUpdateGroupAvatarUrl(groupId: string): string {
        return `${this.environmentService.getApiRoot()}/groups/by-id/${groupId}/picture`;
    }

    getUpdateGroupUrl(groupId: string): string {
        return `${this.environmentService.getApiRoot()}/groups/by-id/${groupId}`;
    }

    getDeleteGroupUrl(groupId: string): string {
        return `${this.environmentService.getApiRoot()}/groups/by-id/${groupId}`;
    }

    getGroupSharedResourcesUrl(groupId: string): string {
        return `${this.environmentService.getApiRoot()}/groups/by-id/${groupId}/shared-resources`;
    }

    async getUserGroupsUrl(): Promise<string> {
        const root = await this.sessionService.getApiRootForUserId()
        return `${root}/groups`;
    }

    async autocompleteUsers(query: string): Promise<UserAutocompleteInfo[]> {
        const url = this.getUserAutocompleteUrl();

        const result = await this.http.get(url, {
            headers: this.sessionService.getAuthHeader(),
            params: { q: query },
        }).toPromise();

        return (result as any)['users'];
    }

    async createGroup(name: string, options: { 'public': boolean, collaborators: { id: string, role: CollaboratorRole }[] } ): Promise<GroupInfo> {
        const url = this.getCreateGroupUrl();

        const result = await this.http.post(url,
                                            JSON.stringify({
                                                name: name,
                                                'public': options['public'],
                                                collaborators: options.collaborators,
                                            }),
                                            {
                                                headers: this.sessionService.addContentType(
                                                    this.sessionService.getAuthHeader(),
                                                    ContentType.Json)
                                            }).toPromise();

        return (result as any)['group'];
    }

    async getUserGroups(): Promise<UserGroupInfo[]> {
        const url = await this.getUserGroupsUrl();

        const result = await this.http.get(url, { headers: this.sessionService.getAuthHeader()})
            .toPromise();

        return (result as any)['groups'].map((group: GroupInfo) => ground(this.environmentService, group, 'picture'));
    }

    async getGroupWithName(groupName: any): Promise<GroupInfo> {
        const url = this.getGroupInfoUrl(groupName);

        const result = await (this.http.get(url, { headers: this.sessionService.getAuthHeader()}).toPromise());

        return (result as any)['group'];
    }

    async getCollaboratorsOnGroup(groupId: string): Promise<Collaborator[]> {
        const url = this.getGroupCollaboratorsUrl(groupId);

        const result = await this.http.get(url, { headers: this.sessionService.getAuthHeader()})
            .toPromise();

        return (result as any)['collaborators'].map((collaborator: Collaborator) => ground(this.environmentService, collaborator, 'picture'));
    }

    async inviteUsers(groupId: string, userIds: { id: string, role: CollaboratorRole }[]): Promise<void> {
        const url = this.updateGroupCollaboratorsUrl(groupId);

        await (this.http
            .post(url,
                  JSON.stringify({
                      action: 'invite',
                      collaborators: userIds.map(user => {
                          return {
                              id: user.id,
                              role: user.role,
                          }}),
                  }),
                  {headers: this.sessionService.addContentType(this.sessionService.getAuthHeader(),
                                                               ContentType.Json)})
            .toPromise());
    }

    async updateGroupCollaboratorList(groupId: string, userIds: { id: string, role: CollaboratorRole }[]): Promise<void> {
        const url = this.updateGroupCollaboratorsUrl(groupId);
        const operatorId = (await this.sessionService.getSession()).user_id;

        const safeCollaborators: { id: string, role: CollaboratorRole }[] = (userIds
            .map((user) => {
                return {
                    id: user.id,
                    role: user.role,
                }})
            .filter((user) => user.id !== operatorId));
        // Make sure that the operator will always be left as admin to be able
        // to correct potential configuration errors
        safeCollaborators.push({ id: operatorId, role: 'admin'});

        await (this.http
            .post(url,
                  JSON.stringify({
                      action: 'update',
                      collaborators: safeCollaborators
                  }),
                  {headers: this.sessionService.addContentType(this.sessionService.getAuthHeader(),
                                                               ContentType.Json)})
            .toPromise());
    }

    async updateGroupAvatar(groupId: string, image: File): Promise<void> {
        const formData = new FormData();
        formData.append('file', image);

        const url = this.getUpdateGroupAvatarUrl(groupId);

        await this.http.post(url, formData, { headers: this.sessionService.getAuthHeader() }).toPromise()
    }

    async setPublicStatus(groupId: string, newStatus: boolean): Promise<void> {
        const url = this.getUpdateGroupUrl(groupId);

        await (this.http
            .patch(url,
                   JSON.stringify({
                       'public': newStatus
                   }),
                   {headers: this.sessionService.addContentType(this.sessionService.getAuthHeader(),
                                                                ContentType.Json)})
            .toPromise());
    }

    async deleteGroup(groupId: string): Promise<void> {
        const url = this.getDeleteGroupUrl(groupId);

        await (this.http
            .delete(url,
                   {headers: this.sessionService.getAuthHeader()})
            .toPromise());
    }

    async getSharedResources(groupId: string): Promise<SharedResource[]> {
        const url = this.getGroupSharedResourcesUrl(groupId);

        const response = await (this.http
            .get(url,
                 {headers: this.sessionService.getAuthHeader()})
            .toPromise());

        return (response as any)['resources'] as SharedResource[];
    }
}

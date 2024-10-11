<script>
import { reactive, onMounted, watch } from 'vue';
import { useProfileStore } from '@/stores/profile.js';

export default {
  setup() {
    const profileStore = useProfileStore();
    const state = reactive({
      userBasicInfo: profileStore.$state.userBasicInfo || [],
      userNetwork: profileStore.$state.userNetwork || []
    });

    onMounted(() => {
      profileStore.loadStore().then(() => {
        state.userBasicInfo = profileStore.$state.userBasicInfo;
        state.userNetwork = profileStore.$state.userNetwork;
      });
    });

    watch(
      () => profileStore.$state,
      (newValue) => {
        state.userBasicInfo = newValue.userBasicInfo;
        state.userNetwork = newValue.userNetwork;
      }
    );

    return {
      state
    };
  },
};
</script>

<template>
  <div class="profile-container">
    <div class="user-basic-info">
      <h2>User Basic Info</h2>
      <ul>
        <li v-for="(info, index) in state.userBasicInfo" :key="index">{{ info }}</li>
      </ul>
    </div>
    <div class="user-network-info">
      <h2>User Network Info</h2>
      <ul>
        <li v-for="(network, index) in state.userNetwork" :key="index">
          <div>
            <h3>Connections</h3>
            <ul>
              <li v-for="(connection, cIndex) in network.connections" :key="cIndex">{{ connection }}</li>
            </ul>
          </div>
          <div>
            <h3>Notifications</h3>
            <ul v-if="network.notifications">
              <li v-for="(notification, nIndex) in network.notifications" :key="nIndex">{{ notification }}</li>
            </ul>
          </div>
          <div>
            <h3>Friends</h3>
            <ul v-if="network.friends">
              <li v-for="(friend, fIndex) in network.friends" :key="fIndex">{{ friend }}</li>
            </ul>
          </div>
          <div>
            <h3>Friend Requests</h3>
            <ul v-if="network.friendRequests">
              <li v-for="(request, rIndex) in network.friendRequests" :key="rIndex">{{ request }}</li>
            </ul>
          </div>
          <div>
            <h3>Blocked Users</h3>
            <ul v-if="network.blockedUsers">
              <li v-for="(user, bIndex) in network.blockedUsers" :key="bIndex">{{ user }}</li>
            </ul>
          </div>
          <div>
            <h3>Following</h3>
            <ul v-if="network.following">
              <li v-for="(user, fIndex) in network.following" :key="fIndex">{{ user }}</li>
            </ul>
          </div>
          <div>
            <h3>Followers</h3>
            <ul v-if="network.followers">
              <li v-for="(user, fIndex) in network.followers" :key="fIndex">{{ user }}</li>
            </ul>
          </div>
          <div>
            <h3>Posts</h3>
            <ul v-if="network.posts">
              <li v-for="(post, pIndex) in network.posts[0]" :key="pIndex">{{ post }}</li>
            </ul>
          </div>
        </li>
      </ul>
    </div>
  </div>
</template>
    
<style scoped>

.profile-container {
padding: 1rem;
margin-top: 2rem;
}

/* Banner */
.profile-banner {
position: relative;
width: 100%;
height: 8rem;
}

.profile-banner img {
width: 100%;
height: 100%;
object-fit: cover;
border-radius: 12px;
}

.banner-mask {
position: absolute;
top: 2.5rem;
width: 100%;
height: 100%;
background: rgba(28, 36, 44, 1);
clip-path: url(#bannerClip); /* Use SVG clip-path */
z-index: 0;
}

.avatar-wrapper {
position: absolute;
top: -4rem;
left: 1.5rem;
width: 128px;
height: 128px;
overflow: hidden;
border-radius: 50%;
}

.profile-avatar {
width: 100%;
height: 100%;
object-fit: cover;

}

/* Responsive Info Section */
.profile-header {
display: flex;
flex-direction: column;
align-items: center;
padding-top: 3rem;
position: relative;
text-align: center;
}

.profile-info {
text-align: left;
margin-left: 0;
width: 100%;
padding-top: .5rem;
}

.username-row {
display: flex;
align-items: center;
}

.profile-title {
font-size: 1.5rem;
color: gray;
margin-bottom: 1px;
font-weight: 600;
}

.profile-username {
font-size: 2.5rem;
margin: 0;
padding: 0;
font-weight: 800;
}

.verified-icon {
margin-left: .5rem;
width: 1.5rem;
}

.profile-id {
display: flex;
align-items: center;
}

.principal-id-label {
color: #aaa; /* Label is lighter */
font-weight: 500;
margin-right: .5rem;
}

.principal-id-text {
color: #00C2FF; /* The actual Principal ID stands out */
font-weight: 600;
}

.principal-icon {
width: 1rem;
margin-right: .25rem;
}

.copy-icon {
width: 1rem;
margin-left: .25rem;
cursor: pointer;
}

.profile-actions {
display: flex;
gap: .5rem;
position: absolute;
right: .25rem;
top: .5rem;
}

.follow-btn{
border-radius: 10px;
width: 8rem;
}

.dm-btn,
.more-btn {
border-radius: 50%;
width: 42px; /* Ensures consistent size */
height: 42px; /* Ensures consistent size */
display: flex;
align-items: center;
justify-content: center;
background-color: #ffffff23;
cursor: pointer;
border: 1px solid #ffffff1d;
}

.follow-btn,
.dm-btn,
.more-btn {
padding: 8px;
border: none;
background-color: #ffffff23;
color: white;
cursor: pointer;
border: .25px solid #ffffff1d;
font-weight: 600;
font-size: .9rem;
font-family: 'Montserrat', sans-serif;
}

.dm-btn img,
.more-btn img {
width: 1.25rem; /* SVG size inside the button */
height: 1.25rem;
}

.follow-btn:hover,
.dm-btn:hover,
.more-btn:hover {
background-color: #ffffff55;
}

/* Links and Info */
.profile-description {
margin: 4px 0;
font-size: 1rem;

}

.profile-links {
display: flex;
gap: 1rem;
font-size: 1rem;
color:#ADADAD;
}

.website {
color: #00C2FF; /* Set to the required color */
text-decoration: none; /* Remove underline */

}

.profile-links img {
width: 1rem;
height: 1rem;
margin-right: .25rem;
margin-bottom: .25rem;
vertical-align: middle; /* Ensures alignment with the text */
}


.followers-count {
font-size: 1.1rem;
font-weight: 600;
}

.followers-count span {
color: white; /* Set the color for the numbers */
}

.followers-count span:nth-child(2n) {
color: #ADADAD; /* Gray color for the text */
font-size: 1rem;

}

.followers-icons {
margin-top: 1rem;
display: flex;
align-items: center;
gap: .25rem;
font-size: .75rem;
color: #ADADAD;
}

.follower-avatar {
width: 32px;
height: 32px;
border-radius: 50%;

}

/* Menu */
.profile-menu {
display: flex;
justify-content: space-around;
border-bottom: 1px solid #333;
margin-bottom: 16px;

}

.profile-menu button {
background: none;
border: none;
color: white;
cursor: pointer;
padding: .5rem;
margin-top: .5rem;
font-weight: 600;
font-family: 'Montserrat', sans-serif;
}

.profile-menu button.active {
border-bottom: 2px solid #00ccff;
}

/* Stats */
.profile-stats {
padding: 20px 0;
}

.stats-grid {
display: grid;
grid-template-columns: repeat(3, 1fr);
gap: 2rem;
}

.stat-item {
display: flex;
flex-direction: column;
align-items: center;
}

.stat-value {
font-size: 2rem;
font-weight: bold;
}

.stat-label {
font-size: 1rem;
color: #888;
}


@media screen and (max-width: 480px) {
.profile-title {
font-size: 1.25rem;
}

.profile-username {
font-size: 2rem;
}

.profile-id {
font-size: 1rem;
}


.profile-description {
font-size: .75rem;
}

.profile-stats .stat-label {
font-size: .5rem;
}

.follow-btn{
width: 88px;
}
.followers-count {
font-size: 1rem;
}

.profile-stats .stat-value {
font-size: 1.5rem;
}

.profile-links {
display: flex;
gap: .5rem;
font-size: .55rem;
}

.banner-mask {
position: absolute;
top: 2.5rem;
background: rgba(28, 36, 44, 1);
clip-path: url(#bannerClip2);
z-index: 0;
}

.avatar-wrapper {
width: 92px;
height: 92px;
}

.dm-btn,
.more-btn {
width: 36px; /* Ensures consistent size */
height: 36px; /* Ensures consistent size */

}
.profile-info {
padding-top: 0rem;
}
}
</style>
    
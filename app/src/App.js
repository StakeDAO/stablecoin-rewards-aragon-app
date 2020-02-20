import React, { useState } from 'react'
import { useAragonApi } from '@aragon/api-react'
import {
  Box,
  Button,
  GU,
  Header,
  Main,
  SyncIndicator,
  Text,
  textStyle,
  TextInput
} from '@aragon/ui'
import styled from 'styled-components'

function App() {
  const { api, appState, currentApp } = useAragonApi()
  const { isSyncing, earned } = appState

  const [stakeAmount, setStakeAmount] = useState(0)
  const [withdrawAmount, setWithdrawAmount] = useState(0)
  const [rewardAmount, setRewardAmount] = useState(0)

  const stake = () => {
    console.log("HOLA")
    api.stake(stakeAmount, {token: { address: currentApp.appAddress, value: stakeAmount }, gas: 500000 }).toPromise()
  }

  return (
    <Main>
      {isSyncing && <SyncIndicator />}
      <Header
        primary="Stablecoin Rewards"
        secondary={
          <Text
            css={`
              ${textStyle('title2')}
            `}
          />
        }
      />

      <Box
        css={`
          display: flex;
          align-items: center;
          justify-content: center;
          text-align: center;
          height: ${50 * GU}px;
          ${textStyle('title3')};
        `}
      >
        Earned: {earned}
        <Buttons>

          <div>
            <TextInput
              value={stakeAmount}
              onChange={event => {setStakeAmount(event.target.value)}}
            />

            <Button
              css={`margin-left: 20px`}
              label="Stake"
              onClick={() => stake()}
            />
          </div>


          <div>
            <TextInput
              value={withdrawAmount}
              onChange={event => {setWithdrawAmount(event.target.value)}}
            />

            <Button
              css={`margin-left: 20px`}
              label="Withdraw"
              onClick={() => api.withdraw(withdrawAmount).toPromise()}
            />
          </div>

          <Button
            label="Claim Reward"
            onClick={() => api.getReward().toPromise()}
          />

          <div>
            <TextInput
              value={rewardAmount}
              onChange={event => {setRewardAmount(event.target.value)}}
            />

            <Button
              css={`margin-left: 20px`}
              label="Distribute Reward"
              onClick={() => api.notifyRewardAmount(rewardAmount).toPromise()}
            />
          </div>

        </Buttons>
      </Box>
    </Main>
  )
}

const Buttons = styled.div`
  display: grid;
  grid-auto-flow: row;
  grid-gap: 40px;
  margin-top: 20px;
`

export default App
